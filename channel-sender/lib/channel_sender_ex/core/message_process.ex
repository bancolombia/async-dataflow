defmodule ChannelSenderEx.Core.MessageProcess do
  @moduledoc """
  Main abstraction for modeling a message delivery process.
  """
  use GenServer, restart: :transient
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
  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @doc false
  @impl true
  def init({channel_ref}) do
    Logger.debug(fn ->
      "MsgProcess: Starting process for channel #{channel_ref}"
    end)

    schedule_work(0)
    {:ok, {channel_ref, %{}, get_param(:max_unacknowledged_retries, @default_retries)}}
  end

  defp schedule_work(retries) do
    Process.send_after(self(), :route_message, calculate_next_redelivery_time(retries))
  end

  @impl true
  def handle_info(:route_message, state) do
    {channel_ref, retry_bag, _max_retries} = state

    get_from_state(channel_ref)
    |> send_messages(retry_bag)
    |> schedule_or_stop(state)
  end

  @spec get_from_state(binary()) :: {any(), any()}
  defp get_from_state(channel) do
    case ChannelPersistence.get_messages(channel) do
      {:ok, [socket, _messages]} when is_nil(socket) or socket == "" ->
        {:error, "No socket found for #{channel} for delivering messages"}

      {:ok, [socket, nil]} ->
        {:noop, socket}

      {:ok, [socket, messages]} ->
        {messages, socket}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp send_messages(msg = {:noop, _socket}, _) do
    msg
  end

  defp send_messages(msg = {:error, reason}, _) do
    Logger.error(fn ->
      "MsgProcess: Error delivering message: #{inspect(reason)}"
    end)

    msg
  end

  defp send_messages({messages, socket_id}, retry_bag) when is_binary(socket_id) and socket_id != "" do

    new_bag = Enum.chunk_every(messages, 2)
    |> Enum.map(fn [msg_id, msg] ->
        case WsConnections.send_data(socket_id, msg) do
          :ok ->
            CustomTelemetry.execute_custom_event([:adf, :message, :delivered], %{count: 1})

          {:error, reason} ->
            CustomTelemetry.execute_custom_event([:adf, :message, :nodelivered], %{count: 1})
            Logger.error(fn ->
              "MsgProcess: Error sending data: #{inspect(reason)}"
            end)
        end
        msg_id
      end)
      |> Enum.reduce(retry_bag, fn (k, acc) ->
        Map.update(acc, k, 1, &(&1 + 1))
      end)

    {:ok, new_bag}
  end

  defp schedule_or_stop({:ok, retry_bag}, state) do
    {channel_ref, _current_bag, max_retries} = state

    new_bag = filter_bag(retry_bag, channel_ref, max_retries)
    if map_size(new_bag) == 0 do
      {:stop, :normal, state}
    else
      schedule_work(0)
      {:noreply, {channel_ref, new_bag, max_retries}}
    end
  end

  defp schedule_or_stop({:error, _reason}, state) do
    # error ocurred
    {:stop, :normal, state}
  end

  defp schedule_or_stop({:noop, _socket}, state) do
    # the message no longer exist in the persistence we can stop the process
    {:stop, :normal, state}
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

  defp filter_bag(retry_bag, channel_ref, max_retries) do
    Enum.reduce(retry_bag, %{}, fn {k, v}, acc ->
      if v >= max_retries do
        Logger.warning(fn ->
          "MsgProcess: max retries for message [#{channel_ref}:#{k}]"
        end)
        ChannelPersistence.delete_message(channel_ref, k)
        acc
      else
        Map.put(acc, k, v)
      end
    end)
  end

  defp get_param(param, def) do
    RulesProvider.get(param)
  rescue
    _e -> def
  end
end
