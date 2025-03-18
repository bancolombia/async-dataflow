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
  alias ChannelSenderEx.Utils.CustomTelemetry
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
    {:ok, {channel_ref, message_id, 1, get_param(:max_unacknowledged_retries, @default_retries)}}
  end

  defp schedule_work(retries) do
    Process.send_after(self(), :route_message, calculate_next_redelivery_time(retries))
  end

  @impl true
  def handle_info(:route_message, state) do
    {channel_ref, message_id, retries, _max_retries} = state

    get_from_state(message_id, channel_ref)
    |> send_message(retries)
    |> schedule_or_stop(state)
  end

  @spec get_from_state(binary(), binary()) :: {any(), any()}
  defp get_from_state(message_id, channel) do
    case ChannelPersistence.get_message(message_id, channel) do
      {:ok, [socket, _message]} when is_nil(socket) or socket == "" ->
        {:error, "No socket found for #{channel} when delivering message #{message_id}"}

      {:ok, [socket, nil]} ->
        {:noop, socket}

      {:ok, [socket, message]} ->
        {message, socket}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp send_message(msg = {:noop, _socket}, _) do
    msg
  end

  defp send_message(msg = {:error, reason}, _) do
    Logger.error(fn ->
      "MsgProcess: Error delivering message: #{inspect(reason)}"
    end)

    msg
  end

  defp send_message({message, socket_id}, retries) when is_binary(socket_id) and socket_id != "" do
    Logger.debug(fn ->
      "MsgProcess: Sending Message #{message} to socket #{socket_id}, try ##{retries}"
    end)
    CustomTelemetry.execute_custom_event([:adf, :message, :requested], %{count: 1})
    # sends to socket id
    case WsConnections.send_data(socket_id, message) do
      :ok ->
        CustomTelemetry.execute_custom_event([:adf, :message, :delivered], %{count: 1})
        :ok

      {:error, reason} = e ->
        CustomTelemetry.execute_custom_event([:adf, :message, :nodelivered], %{count: 1})
        Logger.error(fn ->
          "MsgProcess: Error sending data: #{inspect(reason)}"
        end)

        e
    end
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
