defmodule ChannelSenderEx.Core.MessageProcess do
  @moduledoc """
  Main abstraction for modeling a message delivery process.
  """
  use GenServer
  require Logger

  alias ChannelSenderEx.Adapter.WsConnections
  alias ChannelSenderEx.Core.Data
  alias ChannelSenderEx.Core.BoundedMap
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.RulesProvider
  alias ChannelSenderEx.Persistence.ChannelPersistence
  # alias ChannelSenderEx.Utils.CustomTelemetry
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

  @doc false
  def start_link(args = {_channel_ref, _socket_id, _message}, opts \\ []) do
    GenStateMachine.start_link(__MODULE__, args, opts)
  end

  @doc false
  def init({channel_ref, socket_id, message_id}) do
    schedule_work(0)
    {:ok, {channel_ref, socket_id, message_id, 0, get_param(:max_unacknowledged_retries, 20)}}
  end

  defp schedule_work(retries) do
    Process.send_after(self(), :route_message, calculate_next_redelivery_time(retries))
  end

  @impl true
  def handle_info(:route_message, state) do
    {channel_ref, socket_id, message_id, retries, max_retries} = state

    result = get_from_state(channel_ref)
    |> retrieve_pending(message_id)
    |> send_message(socket_id)

    case result do
      :ok ->
        case retries do
          r when r >= max_retries ->
            Logger.warning(fn -> "Channel #{channel_ref} reached max retries for message #{message_id}" end)
            {:stop, :normal, state}
          _ ->
            Logger.debug(fn ->
              "Channel #{channel_ref} re-delivered message #{message_id} (retry ##{retries + 1})..."
            end)
            schedule_work(retries + 1)
            {:noreply, {channel_ref, socket_id, message_id, retries + 1, max_retries}}
        end
      _ ->
        # the message no longer exist in the persistence we can stop the process
        {:stop, :normal, state}
    end
  end

  @spec get_from_state(binary()) :: {:ok, Data.t()} | :noop
  defp get_from_state(ref) do
    case ChannelPersistence.get_channel_data(ref) do
      {:ok, _loaded_data} = data ->
        data
      {:error, _} ->
        :noop
    end
  end

  defp retrieve_pending({:ok, _data = %{pending: pending}}, ref) do
    case BoundedMap.size(pending) do
      0 -> :noop
      _ ->
        case BoundedMap.pop(pending, ref) do
          {:noop, pending} ->
            {:noop, pending}
          {message, new_pending} ->
            {message, new_pending}
        end
    end
  end

  defp retrieve_pending(:noop, _ref) do
    :noop
  end

  defp send_message(data = {:noop, _}, _socket_id) do
    data
  end

  # @spec send_message(map(), binary()) :: deliver_msg()
  defp send_message(data = {message, _new_pending}, socket_id) do

    # TODO optimize this mess
    new_msg = message
    |> Map.drop(["channel_ref"])
    |> ProtocolMessage.to_protocol_message

    # sends to socket id
    WsConnections.send_data(socket_id,
      ProtocolMessage.to_socket_message(message)
      |> Jason.encode!())

    :ok
  end

  defp calculate_next_redelivery_time(retries) do
    round(exp_back_off(get_param(:initial_redelivery_time, @default_redelivery_time_millis),
      @default_max_backoff_redelivery_millis, retries, 0.2))
  end

  defp get_param(param, def) do
    RulesProvider.get(param)
  rescue
    _e -> def
  end

end
