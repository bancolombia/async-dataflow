defmodule ChannelSenderEx.Core.ChannelWorker do
  @moduledoc """
  Main abstraction for modeling and active or temporarily idle async communication channel with an user.
  """
  use GenServer
  require Logger

  alias ChannelSenderEx.Adapter.WsConnections
  alias ChannelSenderEx.Core.Data
  alias ChannelSenderEx.Core.BoundedMap
  alias ChannelSenderEx.Core.ChannelIDGenerator
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.RulesProvider
  alias ChannelSenderEx.Persistence.ChannelPersistence
  alias ChannelSenderEx.Utils.CustomTelemetry
  import ChannelSenderEx.Core.Retry.ExponentialBackoff, only: [exp_back_off: 4]

  @on_connected_channel_reply_timeout 2000
  @millis_to_seconds 1000
  @default_token_age_seconds 900
  @default_redelivery_time_millis 900
  @default_max_pending_queue 100
  @default_max_backoff_redelivery_millis 1_700

  @type msg_tuple() :: ProtocolMessage.t()
  @type deliver_msg() :: {:deliver_msg, {pid(), String.t()}, msg_tuple()}
  @type pending() :: BoundedMap.t()
  @type deliver_response :: :accepted

  @doc """
  Starts the state machine.
  """
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  @impl true
  def init(_) do
    {:ok, nil}
  end

  @impl true
  def handle_call({:save_channel, channel}, _from, state) do
    {:reply, persist_state(channel), state}
  end

  @impl true
  def handle_call({:get_channel, ref}, _from, state) do
    {:reply, get_from_state(ref), state}
  end

  @impl true
  def handle_call({:delete_channel, ref}, _from, state) do
    Task.start(fn -> ChannelPersistence.delete_channel_data(ref) end)
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:route_message, message}, state) do

    channel_ref = Map.get(message, "channel_ref")
    {:ok, channel} = get_from_state(channel_ref)

    protocol_msg = message
    |> Map.drop(["channel_ref"])
    |> ProtocolMessage.to_protocol_message

    {ref, new_channel} = put_pending(channel_ref, protocol_msg, channel)

    persist_state(new_channel)

    GenServer.start(ChannelSenderEx.Core.MessageProcess, {channel_ref, channel.socket, ref})

    {:noreply, state}
  end

  #########################################
  ###      Support functions           ####
  #########################################

  defp persist_state(data) do
    Task.start(fn -> ChannelPersistence.save_channel_data(data) end)
    data
  end

  @compile {:inline, send_message: 2}
  @spec send_message(Data.t(), map()) :: deliver_msg()
  defp send_message(%{socket: socket_id}, message) do
    # CustomTelemetry.execute_custom_event([:adf, :message, :delivered], %{count: 1})

    # TODO optimize this mess

    new_msg = message
    |> Map.drop(["channel_ref"])
    |> ProtocolMessage.to_protocol_message

    {msg_id, _, _, _, _} = new_msg

    # sends to socket id
    WsConnections.send_data(socket_id,
      ProtocolMessage.to_socket_message(message)
      |> Jason.encode!())

    {msg_id, new_msg}
  end

  @spec get_from_state(binary()) :: {:ok, Data.t()} | :noop
  defp get_from_state(ref) do
    case ChannelPersistence.get_channel_data(ref) do
      {:ok, _loaded_data} = data ->
        Logger.debug(fn -> "Channel #{ref} loaded state sucessfully" end)
        data
      {:error, _} ->
        Logger.debug(fn -> "Channel #{ref} not present in external state." end)
        :noop
    end
  end

  @compile {:inline, put_pending: 3}
  defp put_pending(ref, message, data = %{pending: pending}) do
    Logger.debug("Channel #{data.channel} saving pending ack #{ref}")
    #CustomTelemetry.execute_custom_event([:adf, :channel, :pending, :ack], %{count: 1})
    {ref, %{data | pending: BoundedMap.put(pending, ref, message, get_param(:max_unacknowledged_queue, 100))}}
  end

  defp handle_post_deliver_token({msg_id, new_data}) do
    {:keep_state,
      new_data,
      [
        _redelivery_timeout =
          {{:timeout, {:redelivery, msg_id}},
            get_param(:initial_redelivery_time, @default_redelivery_time_millis), 0},
        _refresh_timeout = {:state_timeout,
          calculate_refresh_token_timeout(), :refresh_token_timeout}
      ]}
  end

  @spec retrieve_pending(Data.t(), reference()) :: {ProtocolMessage.t() | :noop, Data.t()}
  @compile {:inline, retrieve_pending: 2}
  defp retrieve_pending(data = %{pending: pending}, ref) do
    case BoundedMap.size(pending) do
      0 -> {:noop, data}
      _ ->
        case BoundedMap.pop(pending, ref) do
          {:noop, _} ->
            Logger.warning(fn -> "Channel #{data.channel} received ack for unknown message ref #{inspect(ref)}" end)
            {:noop, data}
          {message, new_pending} ->
            {message, %{data | pending: new_pending}}
        end
    end
  end

  # #@spec save_pending(ProtocolMessage.t(), Data.t()) :: Data.t()
  # # @compile {:inline, save_pending: 2}
  # defp save_pending(message = {msg_id, _, _, _, _}, data = %{pending: pending}) do
  #   Logger.debug(fn -> "Channel #{data.channel} saving pending msg #{msg_id}" end)
  #   {msg_id, %{
  #     data
  #     | pending: BoundedMap.put(pending, msg_id, message, get_param(:max_pending_queue,
  #         @default_max_pending_queue))
  #   }}
  # end

  defp process_pending({:noop, data}, _retries, ref) do
    Logger.warning(fn -> "Channel #{data.channel} received redelivery timeout for unknown message ref #{inspect(ref)}" end)
    :keep_state_and_data
  end

  defp process_pending({message = {message_id, _, _, _, _}, data}, retries, ref) do
    max_unacknowledged_retries = get_param(:max_unacknowledged_retries, 20)
    case retries do
      r when r >= max_unacknowledged_retries ->
        Logger.warning(fn -> "Channel #{data.channel} reached max retries for message #{inspect(message_id)}" end)
        {:keep_state, persist_state(data)}

      _ ->
        send_message(data, message)
        Logger.debug(fn ->
          "Channel #{data.channel} re-delivered message #{message_id} (retry ##{retries + 1})..."
        end)
        actions = [
          _timeout =
            {{:timeout, {:redelivery, ref}}, calculate_next_redelivery_time(retries), retries + 1}
        ]
        {:keep_state_and_data, actions}
    end
  end

  @compile {:inline, create_output_message: 2}
  defp create_output_message(message, ref) do
    {ref, message}
  end



  defp calculate_next_redelivery_time(retries) do
    round(exp_back_off(get_param(:initial_redelivery_time, @default_redelivery_time_millis),
      @default_max_backoff_redelivery_millis, retries, 0.2))
  end

  @spec calculate_refresh_token_timeout() :: integer()
  @compile {:inline, calculate_refresh_token_timeout: 0}
  defp calculate_refresh_token_timeout do
    token_validity = get_param(:max_age, @default_token_age_seconds)
    tolerance = get_param(:min_disconnection_tolerance, 50)
    min_timeout = token_validity / 2
    round(max(min_timeout, token_validity - tolerance) * @millis_to_seconds)
  end

  defp estimate_process_wait_time(data) do
    # when is a new socket connection this will resolve false
    case socket_clean_disconnection?(data) do
      true ->
        round(get_param(:channel_shutdown_on_clean_close, 30) * @millis_to_seconds)
      false ->
        # this time will also apply when socket the first time connected
        round(get_param(:channel_shutdown_on_disconnection, 300) * @millis_to_seconds)
    end
  end

  defp socket_clean_disconnection?(data) do
    case data.socket_stop_cause do
      :normal -> true
      {:remote, 1000, _} -> true
      _ -> false
    end
  end

  defp load_state_from_external(channel, from_state) when from_state == :waiting do
    Logger.debug(fn -> "Channel #{channel.channel} searching data in persistence." end)
    case ChannelPersistence.get_channel_data(channel.channel) do
      {:ok, loaded_data} ->
        Logger.debug(fn -> "Channel #{channel.channel} loaded state sucessfully" end)
        loaded_data
      {:error, _} ->
        Logger.debug(fn -> "Channel #{channel.channel} not present in external state. Starting fresh." end)
        channel
    end
  end

  defp load_state_from_external(channel, _from_state) do
    Logger.debug(fn -> "Channel #{channel.channel} not searching data in persistence." end)
    channel
  end

  defp decide_next_state_from_waiting(channel_data) do
    case estimate_process_wait_time(channel_data) do
      0 ->
        Logger.info(fn -> "Channel #{channel_data.channel} will not remain in waiting state due calculated wait time is 0. Stopping now." end)
        #{:next_state, :closed, %{channel_data | stop_cause: :waiting_time_zero}}
        {:keep_state,
          %{channel_data | socket_stop_cause: :waiting_time_zero},
          [{:state_timeout, 0, :waiting_timeout}]}

      waiting ->
        Logger.info(fn ->
          "Channel #{inspect(channel_data.channel)} entering waiting state. Expecting a socket connection/authentication. max wait time: #{waiting} ms"
        end)
        {:keep_state,
          %{channel_data | socket_stop_cause: nil},
          [{:state_timeout, waiting, :waiting_timeout}]}
    end
  end

  defp build_actions_for_pending(data) do
    case BoundedMap.size(data.pending) do
      0 ->
        []
      _ ->
        Logger.debug(fn -> "Channel #{data.channel} has pending messages to send" end)
        Enum.map(BoundedMap.to_map(data.pending), fn {_k, v} -> List.to_tuple(v) end)
        |> Enum.map(fn {msg_id, _, _, _, _} ->
          {{:timeout, {:redelivery, msg_id}},
            redelidery_time_minus_drift(get_param(:initial_redelivery_time, @default_redelivery_time_millis)),
            0}
        end)
    end
  end

  defp redelidery_time_minus_drift(time) do
    time + :rand.uniform(100)
  end

  defp get_param(param, def) do
    RulesProvider.get(param)
  rescue
    _e -> def
  end

end
