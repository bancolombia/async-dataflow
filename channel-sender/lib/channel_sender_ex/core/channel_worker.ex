defmodule ChannelSenderEx.Core.ChannelWorker do
  @moduledoc """
  Main abstraction for modeling and active or temporarily idle async communication channel_ref with an user.
  """
  use GenServer
  require Logger

  alias ChannelSenderEx.Adapter.WsConnections
  alias ChannelSenderEx.Core.BoundedMap
  alias ChannelSenderEx.Core.Data
  alias ChannelSenderEx.Core.MessageProcessSupervisor
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.RulesProvider
  alias ChannelSenderEx.Persistence.ChannelPersistence

  @type msg_tuple() :: ProtocolMessage.t()
  @type deliver_msg() :: {:deliver_msg, {pid(), String.t()}, msg_tuple()}
  @type pending() :: BoundedMap.t()
  @type deliver_response :: :accepted

  @pool_name :channel_worker

  ##########################################
  ###          poolboy wrappers          ###
  ##########################################

  def pool_child_spec(opts) do
    poolboy_config = [
      name: {:local, @pool_name},
      worker_module: __MODULE__,
      size: Keyword.get(opts, :size, 80),
      max_overflow: Keyword.get(opts, :max_overflow, 20)
    ]

    :poolboy.child_spec(@pool_name, poolboy_config)
  end

  def save_channel(data) do
    pool_cast({:save_channel, data})
  end

  def get_channel(channel_ref) do
    pool_call({:get_channel, channel_ref})
  end

  def save_socket_data(channel_ref, connection_id) do
    pool_cast({:save_socket_data, channel_ref, connection_id})
  end

  def delete_channel(channel_ref) do
    pool_cast({:delete_channel, channel_ref})
  end

  def accept_socket(channel_ref, connection_id) do
    pool_cast({:accept_socket, channel_ref, connection_id})
  end

  def disconnect_socket(connection_id) do
    pool_cast({:disconnect_socket, connection_id})
  end

  def ack_message(connection_id, message_id) do
    pool_cast({:ack_message, connection_id, message_id})
  end

  def route_message(message) do
    pool_cast({:route_message, message})
  end

  def pool_cast(action) do
    :poolboy.transaction(@pool_name, fn pid -> GenServer.cast(pid, action) end)
  end

  def pool_call(action) do
    :poolboy.transaction(@pool_name, fn pid -> GenServer.call(pid, action) end)
  end

  ##########################################
  ###        GenServer callbacks         ###
  ##########################################

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  @impl true
  def init(_) do
    {:ok, nil}
  end

  @impl true
  def handle_call({:get_channel, channel_ref}, _from, state) do
    {:reply, ChannelPersistence.get_channel_data(channel_ref), state}
  end

  @impl true
  def handle_cast({:save_channel, data}, state) do
    ChannelPersistence.save_channel_data(data)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:save_socket_data, channel_ref, connection_id}, state) do
    ChannelPersistence.save_socket_data(channel_ref, connection_id)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete_channel, channel_ref}, state) do
    case ChannelPersistence.get_channel_data(channel_ref) do
      {:ok, data} ->
        delete_channel_and_close_socket(data)

      {:error, _} ->
        Logger.info("No channel found for channel_ref #{channel_ref}")
    end

    # Drop socket connection too
    {:noreply, state}
  end

  @impl true
  def handle_cast({:accept_socket, channel_ref, connection_id}, state) do
    key = "channel_#{channel_ref}"

    case ChannelPersistence.get_channel_data(key) do
      {:ok, data} ->
        ChannelPersistence.save_channel_data(Data.set_socket(data, connection_id))

      {:error, _} ->
        Logger.info("No channel found with channel_ref #{channel_ref}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:disconnect_socket, connection_id}, state) do
    case ChannelPersistence.get_channel_data("socket_#{connection_id}") do
      {:ok, channel_ref} ->
        Logger.info("Disconnecting socket #{connection_id} from channel #{inspect(channel_ref)}")
        remove_socket_from_channel(channel_ref, connection_id)

      {:error, _} ->
        Logger.info("No channel found for socket connection #{inspect(connection_id)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:ack_message, connection_id, message_id}, state) do
    case ChannelPersistence.get_channel_data("socket_#{connection_id}") do
      {:ok, channel_ref} ->
        remove_message_and_save(channel_ref, message_id)

      {:error, _} ->
        Logger.info("No channel found for socket #{connection_id}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:route_message,
         message = %{"channel_ref" => _channel_ref, "message_id" => _msg_id}},
        state
      ) do
    route_single_message(message)
    {:noreply, state}
  end

  defp route_single_message(message = %{"channel_ref" => channel_ref, "message_id" => msg_id}) do
    with {:ok, data} <- ChannelPersistence.get_channel_data("channel_#{channel_ref}"),
      protocol_msg <- ProtocolMessage.to_protocol_message(message),
      new_data when is_map(new_data) <- put_pending(data, protocol_msg),
      :ok <- ChannelPersistence.save_channel_data(new_data) do
      MessageProcessSupervisor.start_message_process({channel_ref, msg_id})
    else
      error ->
        Logger.error("Error routing message with id: #{msg_id} #{inspect(error)}")
    end
  end

  #########################################
  ###      Support functions           ####
  #########################################

  @compile {:inline, put_pending: 2}
  defp put_pending(data = %Data{pending: pending, channel: channel_ref}, message) do
    message_id = ProtocolMessage.message_id(message)
    Logger.debug("Channel #{channel_ref} saving pending message id #{message_id}")
    # CustomTelemetry.execute_custom_event([:adf, :channel_ref, :pending, :ack], %{count: 1})
    max_size = get_param(:max_unacknowledged_queue, 100)
    new_pending = BoundedMap.put(pending, message_id, message, max_size)

    Data.set_pending(data, new_pending)
  end

  defp remove_socket_from_channel(channel_ref, connection_id) do
    Logger.info("Removing socket #{connection_id} from channel #{channel_ref}")

    case ChannelPersistence.get_channel_data("channel_#{channel_ref}") do
      {:ok, data = %{socket: ^connection_id}} ->
        ChannelPersistence.save_channel_data(Data.set_socket(data, nil))

      _other ->
        Logger.info("No channel found for socket connection #{connection_id}")
    end

    ChannelPersistence.delete_channel_data("socket_#{connection_id}")
  end

  defp remove_message_and_save(channel_ref, message_id) do
    with {:ok, data = %{pending: pending}} <-
           ChannelPersistence.get_channel_data("channel_#{channel_ref}"),
         {msg, bounded_map} when msg != :noop <- BoundedMap.pop(pending, message_id) do
      ChannelPersistence.save_channel_data(Data.set_pending(data, bounded_map))
    else
      _other ->
        Logger.info("No message found with id #{message_id} when ack")
        :ok
    end
  end

  defp delete_channel_and_close_socket(%{channel: channel, socket: connection_id})
       when is_binary(connection_id) and connection_id != "" do
    ChannelPersistence.delete_channel_data("channel_#{channel}")
    ChannelPersistence.delete_channel_data("socket_#{connection_id}")
    WsConnections.close(connection_id)
  end

  defp delete_channel_and_close_socket(%{channel: channel}) do
    ChannelPersistence.delete_channel_data("channel_#{channel}")
  end

  defp get_param(param, def) do
    RulesProvider.get(param)
  rescue
    _e -> def
  end

end
