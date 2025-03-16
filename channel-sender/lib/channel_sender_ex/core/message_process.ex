defmodule ChannelSenderEx.Core.MessageProcess do
  @moduledoc """
  Main abstraction for modeling a message delivery process.
  """
  use GenServer
  require Logger

  alias ChannelSenderEx.Adapter.WsConnections
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.RulesProvider
  alias ChannelSenderEx.Persistence.ChannelPersistence
  # alias ChannelSenderEx.Utils.CustomTelemetry
  import ChannelSenderEx.Core.Retry.ExponentialBackoff, only: [exp_back_off: 4]

  @default_redelivery_time_millis 900
  @default_max_backoff_redelivery_millis 1_700
  @default_retries 20

  @type msg_tuple() :: ProtocolMessage.t()
  @type deliver_msg() :: {:deliver_msg, {pid(), String.t()}, msg_tuple()}
  @type deliver_response :: :accepted

  @doc false
  def start_link(args = {_channel_ref, _message_id}, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @doc false
  @impl true
  def init({channel_ref, message_id}) do
    Logger.debug(fn ->
      "MsgProcess: Starting process for channel #{channel_ref} and message #{message_id}"
    end)
    schedule_work(0)
    {:ok, {channel_ref, message_id, 0, get_param(:max_unacknowledged_retries, @default_retries)}}
  end

  defp schedule_work(retries) do
    Process.send_after(self(), :route_message, calculate_next_redelivery_time(retries))
  end

  @impl true
  def handle_info(:route_message, state) do
    {channel_ref, message_id, _retries, _max_retries} = state

    get_from_state(message_id, channel_ref)
    |> send_message()
    |> schedule_or_stop(state)
  end

  @spec get_from_state(binary(), binary()) :: {any(), any()}
  defp get_from_state(message_id, channel) do
    {:ok, [socket | message]} = ChannelPersistence.get_message(message_id, channel)
    case List.first(message) do
      nil ->
        Logger.debug(fn ->
          "MsgProcess: message #{message_id} no longer exists in the persistence"
        end)
        {:noop, socket}
      _ ->
        {Jason.decode!(message) |> ProtocolMessage.to_socket_message, socket}
    end
  end

  defp send_message(msg = {:noop, _socket}) do
    msg
  end

  defp send_message({message, socket_id}) when is_binary(socket_id) and socket_id != "" do
    Logger.debug(fn ->
      "MsgProcess: Sending message #{inspect(message)} to socket [#{socket_id}]"
    end)
    # sends to socket id
    # TODO: handle errors
    case WsConnections.send_data(socket_id, message |> Jason.encode!()) do
      :ok -> :ok
      {:error, reason} = e ->
        Logger.error(fn ->
          "MsgProcess: Error sending #{inspect(reason)}"
        end)
        e
    end
  end

  defp send_message(data = {message, socket_id})  when is_nil(socket_id) or socket_id == "" do
    [msg_id | _] = message
    Logger.warning(fn ->
      "MsgProcess: Not sending message #{msg_id} to an non-valid socket-id"
    end)
    data
  end

  defp schedule_or_stop({:noop, _socket}, state) do
    # the message no longer exist in the persistence we can stop the process
    {:stop, :normal, state}
  end

  defp schedule_or_stop(_other, state) do
    {channel_ref, message_id, retries, max_retries} = state

    if retries >= max_retries do
      Logger.warning(fn ->
        "MsgProcess: max retries for message [#{message_id}] on channel [#{channel_ref}]"
      end)
      ChannelPersistence.delete_message(message_id)
      {:stop, :normal, state}
    else
      Logger.debug(fn ->
        "MsgProcess: Message #{message_id} re-delivered (retry ##{retries + 1})..."
      end)

      schedule_work(retries + 1)
      {:noreply, {channel_ref, message_id, retries + 1, max_retries}}
    end
  end

  defp calculate_next_redelivery_time(retries) do
    round(
      exp_back_off(
        get_param(:initial_redelivery_time, @default_redelivery_time_millis),
        @default_max_backoff_redelivery_millis,
        retries,
        0.2
      )
    )
  end

  defp get_param(param, def) do
    RulesProvider.get(param)
  rescue
    _e -> def
  end
end
