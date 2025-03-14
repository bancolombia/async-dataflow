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
    key = "socket_#{connection_id}"

    case ChannelPersistence.get_channel_data(key) do
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
         message = %{"channel_ref" => channel_ref, "message_id" => msg_id}},
        state
      ) do
    with {:ok, data} <- ChannelPersistence.get_channel_data("channel_#{channel_ref}"),
         protocol_msg <- ProtocolMessage.to_protocol_message(message),
         new_data when is_map(new_data) <- put_pending(data, protocol_msg),
         :ok <- ChannelPersistence.save_channel_data(new_data) do
      MessageProcessSupervisor.start_message_process({channel_ref, msg_id})
    else
      error ->
        Logger.error("Error routing message with id: #{msg_id} #{inspect(error)}")
    end

    {:noreply, state}
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

  # @compile {:inline, send_message: 2}
  # @spec send_message(Data.t(), map()) :: deliver_msg()
  # defp send_message(%{socket: socket_id}, message) do
  #   # CustomTelemetry.execute_custom_event([:adf, :message, :delivered], %{count: 1})

  #   # TODO optimize this mess

  #   new_msg =
  #     message
  #     |> Map.drop(["channel_channel_ref"])
  #     |> ProtocolMessage.to_protocol_message()

  #   {msg_id, _, _, _, _} = new_msg

  #   # sends to socket id
  #   WsConnections.send_data(
  #     socket_id,
  #     ProtocolMessage.to_socket_message(message)
  #     |> Jason.encode!()
  #   )

  #   {msg_id, new_msg}
  # end

  # defp handle_post_deliver_token({msg_id, new_data}) do
  #   {:keep_state, new_data,
  #    [
  #      _redelivery_timeout =
  #        {{:timeout, {:redelivery, msg_id}},
  #         get_param(:initial_redelivery_time, @default_redelivery_time_millis), 0},
  #      _channel_refresh_timeout =
  #        {:state_timeout, calculate_channel_refresh_token_timeout(),
  #         :channel_refresh_token_timeout}
  #    ]}
  # end

  # @spec retrieve_pending(Data.t(), channel_reference()) :: {ProtocolMessage.t() | :noop, Data.t()}
  # @compile {:inline, retrieve_pending: 2}
  # defp retrieve_pending(data = %{pending: pending}, channel_ref) do
  #   case BoundedMap.size(pending) do
  #     0 ->
  #       {:noop, data}

  #     _ ->
  #       case BoundedMap.pop(pending, channel_ref) do
  #         {:noop, _} ->
  #           Logger.warning(fn ->
  #             "Channel #{data.channel_ref} received ack for unknown message channel_ref #{inspect(channel_ref)}"
  #           end)

  #           {:noop, data}

  #         {message, new_pending} ->
  #           {message, %{data | pending: new_pending}}
  #       end
  #   end
  # end

  # #@spec save_pending(ProtocolMessage.t(), Data.t()) :: Data.t()
  # # @compile {:inline, save_pending: 2}
  # defp save_pending(message = {msg_id, _, _, _, _}, data = %{pending: pending}) do
  #   Logger.debug(fn -> "Channel #{data.channel_ref} saving pending msg #{msg_id}" end)
  #   {msg_id, %{
  #     data
  #     | pending: BoundedMap.put(pending, msg_id, message, get_param(:max_pending_queue,
  #         @default_max_pending_queue))
  #   }}
  # end

  # defp process_pending({:noop, data}, _retries, channel_ref) do
  #   Logger.warning(fn ->
  #     "Channel #{data.channel_ref} received redelivery timeout for unknown message channel_ref #{inspect(channel_ref)}"
  #   end)

  #   :keep_state_and_data
  # end

  # defp process_pending({message = {message_id, _, _, _, _}, data}, retries, channel_ref) do
  #   max_unacknowledged_retries = get_param(:max_unacknowledged_retries, 20)

  #   case retries do
  #     r when r >= max_unacknowledged_retries ->
  #       Logger.warning(fn ->
  #         "Channel #{data.channel_ref} reached max retries for message #{inspect(message_id)}"
  #       end)

  #       {:keep_state, persist_state(data)}

  #     _ ->
  #       send_message(data, message)

  #       Logger.debug(fn ->
  #         "Channel #{data.channel_ref} re-delivered message #{message_id} (retry ##{retries + 1})..."
  #       end)

  #       actions = [
  #         _timeout =
  #           {{:timeout, {:redelivery, channel_ref}}, calculate_next_redelivery_time(retries),
  #            retries + 1}
  #       ]

  #       {:keep_state_and_data, actions}
  #   end
  # end

  # @compile {:inline, create_output_message: 2}
  # defp create_output_message(message, channel_ref) do
  #   {channel_ref, message}
  # end

  # defp calculate_next_redelivery_time(retries) do
  #   round(
  #     exp_back_off(
  #       get_param(:initial_redelivery_time, @default_redelivery_time_millis),
  #       @default_max_backoff_redelivery_millis,
  #       retries,
  #       0.2
  #     )
  #   )
  # end

  # @spec calculate_channel_refresh_token_timeout() :: integer()
  # @compile {:inline, calculate_channel_refresh_token_timeout: 0}
  # defp calculate_channel_refresh_token_timeout do
  #   token_validity = get_param(:max_age, @default_token_age_seconds)
  #   tolerance = get_param(:min_disconnection_tolerance, 50)
  #   min_timeout = token_validity / 2
  #   round(max(min_timeout, token_validity - tolerance) * @millis_to_seconds)
  # end

  # defp estimate_process_wait_time(data) do
  #   # when is a new socket connection this will resolve false
  #   case socket_clean_disconnection?(data) do
  #     true ->
  #       round(get_param(:channel_shutdown_on_clean_close, 30) * @millis_to_seconds)

  #     false ->
  #       # this time will also apply when socket the first time connected
  #       round(get_param(:channel_shutdown_on_disconnection, 300) * @millis_to_seconds)
  #   end
  # end

  # defp socket_clean_disconnection?(data) do
  #   case data.socket_stop_cause do
  #     :normal -> true
  #     {:remote, 1000, _} -> true
  #     _ -> false
  #   end
  # end

  # defp load_state_from_external(channel_ref, from_state) when from_state == :waiting do
  #   Logger.debug(fn -> "Channel #{channel_ref.channel_ref} searching data in persistence." end)

  #   case ChannelPersistence.get_channel_data(channel_ref.channel_ref) do
  #     {:ok, loaded_data} ->
  #       Logger.debug(fn -> "Channel #{channel_ref.channel_ref} loaded state sucessfully" end)
  #       loaded_data

  #     {:error, _} ->
  #       Logger.debug(fn ->
  #         "Channel #{channel_ref.channel_ref} not present in external state. Starting fresh."
  #       end)

  #       channel_ref
  #   end
  # end

  # defp load_state_from_external(channel_ref, _from_state) do
  #   Logger.debug(fn ->
  #     "Channel #{channel_ref.channel_ref} not searching data in persistence."
  #   end)

  #   channel_ref
  # end

  # defp decide_next_state_from_waiting(channel_data) do
  #   case estimate_process_wait_time(channel_data) do
  #     0 ->
  #       Logger.info(fn ->
  #         "Channel #{channel_data.channel_ref} will not remain in waiting state due calculated wait time is 0. Stopping now."
  #       end)

  #       # {:next_state, :closed, %{channel_data | stop_cause: :waiting_time_zero}}
  #       {:keep_state, %{channel_data | socket_stop_cause: :waiting_time_zero},
  #        [{:state_timeout, 0, :waiting_timeout}]}

  #     waiting ->
  #       Logger.info(fn ->
  #         "Channel #{inspect(channel_data.channel_ref)} entering waiting state. Expecting a socket connection/authentication. max wait time: #{waiting} ms"
  #       end)

  #       {:keep_state, %{channel_data | socket_stop_cause: nil},
  #        [{:state_timeout, waiting, :waiting_timeout}]}
  #   end
  # end

  # defp build_actions_for_pending(data) do
  #   case BoundedMap.size(data.pending) do
  #     0 ->
  #       []

  #     _ ->
  #       Logger.debug(fn -> "Channel #{data.channel_ref} has pending messages to send" end)

  #       Enum.map(BoundedMap.to_map(data.pending), fn {_k, v} -> List.to_tuple(v) end)
  #       |> Enum.map(fn {msg_id, _, _, _, _} ->
  #         {{:timeout, {:redelivery, msg_id}},
  #          redelidery_time_minus_drift(
  #            get_param(:initial_redelivery_time, @default_redelivery_time_millis)
  #          ), 0}
  #       end)
  #   end
  # end

  # defp redelidery_time_minus_drift(time) do
  #   time + :rand.uniform(100)
  # end
end
