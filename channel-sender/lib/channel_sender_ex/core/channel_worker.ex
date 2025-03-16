defmodule ChannelSenderEx.Core.ChannelWorker do
  @moduledoc """
  Main abstraction for modeling and active or temporarily idle async communication channel_ref with an user.
  """
  use GenServer
  require Logger

  alias ChannelSenderEx.Adapter.WsConnections
  alias ChannelSenderEx.Core.MessageProcessSupervisor
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Persistence.ChannelPersistence

  @type msg_tuple() :: ProtocolMessage.t()
  @type deliver_msg() :: {:deliver_msg, {pid(), String.t()}, msg_tuple()}
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

  def save_channel(channel, socket \\ "") do
    pool_cast({:save_channel, channel, socket})
  end

  def get_channel(channel_ref) do
    pool_call({:get_channel, channel_ref})
  end

  def get_socket(socket) do
    pool_call({:get_socket, socket})
  end

  def save_socket(channel_ref, connection_id) do
    pool_cast({:save_socket, channel_ref, connection_id})
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

  def disconnect_raw_socket(connection_id, reason) do
    pool_cast({:disconnect_raw_socket, connection_id, reason})
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
    {:reply, ChannelPersistence.get_channel(channel_ref), state}
  end

  @impl true
  def handle_call({:get_socket, socket}, _from, state) do
    {:reply, ChannelPersistence.get_socket(socket), state}
  end

  @impl true
  def handle_cast({:save_channel, channel, socket}, state) do
    ChannelPersistence.save_channel(channel, socket)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:save_socket, channel_ref, connection_id}, state) do
    ChannelPersistence.save_socket(channel_ref, connection_id)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete_channel, channel_ref}, state) do
    case ChannelPersistence.get_channel(channel_ref) do
      {:ok, connection_id} ->
        Logger.debug(fn -> "ChWorker: Removing all info from channel [#{channel_ref}] and socket [#{connection_id}]" end)
        ChannelPersistence.delete_channel(channel_ref, connection_id)
        send_close_socket_signal(connection_id)

        {:error, _} ->
          Logger.debug(fn -> "ChWorker: No channel found for channel_ref #{channel_ref}" end)
    end

    # Drop socket connection too
    {:noreply, state}
  end

  @impl true
  def handle_cast({:accept_socket, channel_ref, connection_id}, state) do
    case ChannelPersistence.get_channel(channel_ref) do
      {:ok, _data} ->
        ChannelPersistence.save_channel(channel_ref, connection_id)

      {:error, _} ->
        Logger.debug(fn -> "ChWorker: No channel found with channel_ref #{channel_ref}" end)
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:disconnect_socket, connection_id}, state) do
    case ChannelPersistence.get_socket(connection_id) do
      {:ok, channel_ref} ->
        Logger.debug(fn -> "ChWorker: Removing socket [#{connection_id}] info and removing relation to channel [#{channel_ref}]" end)
        ChannelPersistence.delete_socket(connection_id, channel_ref)
        send_close_socket_signal(connection_id)

      {:error, _} ->
        Logger.debug(fn -> "ChWorker: No channel found for socket connection #{inspect(connection_id)}" end)
    end
    {:noreply, state}
  end

  # only use this to disconnect a socket connection that it's not related to a channel yet
  @impl true
  def handle_cast({:disconnect_raw_socket, connection_id, response_code}, state) do
    Logger.debug(fn -> "ChWorker: Disconnecting socket connection #{connection_id} with response code #{response_code}" end)

    WsConnections.send_data(connection_id, "[\"\",\"#{response_code}\", \"\", \"\"]")
    Process.sleep(50)
    send_close_socket_signal(connection_id)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:ack_message, _connection_id, message_id}, state) do
    Logger.debug(fn -> "ChWorker: Ack message #{message_id}" end)
    ChannelPersistence.delete_message(message_id)
    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:route_message,
         message = %{"channel_ref" => channel_ref, "message_id" => msg_id}},
        state
      ) do
      # ChannelPersistence.get_channel(channel_ref)
      # |> case do
      #   {:ok, _} ->
          ChannelPersistence.save_message(msg_id, Map.drop(message, ["channel_ref"]))
          MessageProcessSupervisor.start_message_process({channel_ref, msg_id})
      #   {:error, _} ->
      #     Logger.error("ChWorker: No channel found [#{channel_ref}], message [#{msg_id}] will not be routed")
      # end
      {:noreply, state}
  end

  defp send_close_socket_signal(connection_id) when is_binary(connection_id) and connection_id != "" do
    WsConnections.close(connection_id)
  end

  defp send_close_socket_signal(connection_id) when is_nil(connection_id) or connection_id == "" do
    # socket id rerefence no longer exists
    :ok
  end

end
