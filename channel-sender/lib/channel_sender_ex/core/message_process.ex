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

  @default_redelivery_time_millis 900
  @default_max_backoff_redelivery_millis 1_700
  @default_retries 20

  @type msg_tuple() :: ProtocolMessage.t()
  @type deliver_msg() :: {:deliver_msg, {pid(), String.t()}, msg_tuple()}
  @type pending() :: BoundedMap.t()
  @type deliver_response :: :accepted

  @doc false
  def start_link(args = {_channel_ref, _message_id}, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @doc false
  @impl true
  def init({channel_ref, message_id}) do
    Logger.debug(fn ->
      "Starting message process for channel #{channel_ref} and message #{message_id}"
    end)
    initial_retries = 0
    schedule_work(initial_retries)
    max_retries = get_param(:max_unacknowledged_retries, @default_retries)

    {:ok, {channel_ref, message_id, initial_retries, max_retries}}
  end

  defp schedule_work(retries) do
    Process.send_after(self(), :route_message, calculate_next_redelivery_time(retries))
  end

  @impl true
  def handle_info(:route_message, state) do
    {channel_ref, message_id, _retries, _max_retries} = state

    get_from_state(channel_ref)
    |> retrieve_pending(message_id)
    |> send_message()
    |> schedule_or_stop(state)
  end

  @spec get_from_state(binary()) :: {:ok, Data.t()} | :noop
  defp get_from_state(ref) do
    case ChannelPersistence.get_channel_data("channel_#{ref}") do
      {:ok, data} ->
        data

      {:error, _} ->
        :noop
    end
  end

  defp retrieve_pending(:noop, _message_id), do: :noop
  defp retrieve_pending(%{socket: socket}, message_id) when is_nil(socket) or socket == "" do
    Logger.warning("No socket found routing message #{message_id}")
    :no_socket
  end

  defp retrieve_pending(%{pending: pending, socket: connection_id}, message_id) do
    Logger.debug(fn ->
      "Retrieving message #{message_id} from pending list for connection #{connection_id}"
    end)
    case BoundedMap.pop(pending, message_id) do
      {:noop, _bounded_map} ->
        :noop

      {message, _new_pending} ->
        {message, connection_id}
    end
  end

  defp send_message(:noop) do
    Logger.warning(fn ->
      ":noop message"
    end)
    :noop
  end
  defp send_message(:no_socket) do
    Logger.warning(fn ->
      ":nosocket message"
    end)
    :no_socket
  end
  defp send_message({message, socket_id}) do
    socket_message =
      ProtocolMessage.to_socket_message(message)
      |> Jason.encode!()
    Logger.debug(fn ->
      "Sending message #{socket_message} to socket #{socket_id}"
    end)
    # sends to socket id
    # TODO: handle errors
    WsConnections.send_data(socket_id, socket_message)
    :ok
  end

  defp schedule_or_stop(:noop, state) do
    # the message no longer exist in the persistence we can stop the process
    {:stop, :normal, state}
  end

  defp schedule_or_stop(_other, state) do
    {channel_ref, message_id, retries, max_retries} = state

    if retries >= max_retries do
      Logger.warning(fn ->
        "Channel #{channel_ref} reached max retries for message #{message_id}"
      end)

      {:stop, :normal, state}
    else
      Logger.debug(fn ->
        "Channel #{channel_ref} re-delivered message #{message_id} (retry ##{retries + 1})..."
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
