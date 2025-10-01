defmodule ChannelSenderEx.Core.PubSub.ReConnectProcess do
  @moduledoc false

  alias ChannelSenderEx.Core.Channel
  alias ChannelSenderEx.Core.ChannelSupervisor

  import ChannelSenderEx.Core.Retry.ExponentialBackoff, only: [execute: 6]
  require Logger

  @type kind() :: :websocket | :sse | :longpoll

  @max_retries 11
  @min_backoff 50
  @max_backoff 3000

  @spec start(pid(), binary(), kind(), keyword()) :: {:ok, pid()}
  def start(socket_pid, channel_ref, kind, options \\ []) do
    Task.start_link(fn ->
      new_pid = start_internal(socket_pid, channel_ref, kind, options)
      send(socket_pid, {:monitor_channel, channel_ref, new_pid})
    end)
  end

  def start_internal(socket_pid, channel_ref, kind, options) do
    Logger.debug(fn -> "Starting re-connection process for channel #{channel_ref}" end)
    action_function = create_action(channel_ref, socket_pid, Process.monitor(socket_pid), kind)

    execute(
      Keyword.get(options, :min_backoff, @min_backoff),
      Keyword.get(options, :max_backoff, @max_backoff),
      Keyword.get(options, :max_retries, @max_retries),
      action_function,
      fn -> start_channel(channel_ref, socket_pid, kind) end,
      "reconnect_channel_#{channel_ref}"
    )
  end

  def create_action(channel_ref, socket_pid, socket_mon_ref, kind) do
    fn actual_delay ->
      case connect_socket_to_channel(channel_ref, socket_pid, kind) do
        :noproc ->
          receive do
            {:DOWN, ^socket_mon_ref, _, _pid, :noproc} -> :void
          after
            actual_delay -> :retry
          end

        result ->
          result
      end
    end
  end

  def connect_socket_to_channel(channel_ref, socket_pid, kind) do
    case ChannelSupervisor.whereis_channel(channel_ref) do
      :undefined ->
        :noproc

      pid when is_pid(pid) ->
        connect_socket_to_pid(channel_ref, socket_pid, pid, kind)
        pid
    end
  catch
    _type, err ->
      Logger.error(fn -> "Error connecting #{kind} to channel #{inspect(err)}" end)
      :noproc
  end

  def start_channel(channel_ref, socket_pid, kind) do
    case ChannelSupervisor.register_channel({channel_ref, "", "", []}) do
      {:ok, pid} ->
        Logger.debug(fn ->
          "Re-connection process for channel #{channel_ref} solved with new channel pid: #{inspect(pid)}"
        end)

        connect_socket_to_pid(channel_ref, socket_pid, pid, kind)
        pid

      other ->
        Logger.error(fn ->
          "Re-connection process for channel #{channel_ref} failed: #{inspect(other)}"
        end)

        other
    end
  end

  defp connect_socket_to_pid(channel_ref, socket_pid, pid, kind) do
    Logger.debug(fn ->
      "Connecting #{kind} with pid #{inspect(socket_pid)} to channel #{channel_ref} with pid #{inspect(pid)}"
    end)

    timeout = Application.get_env(:channel_sender_ex, :on_connected_channel_reply_timeout)

    case kind do
      :websocket ->
        Channel.socket_connected(pid, socket_pid, timeout)

      :sse ->
        Channel.sse_connected(pid, socket_pid, timeout)

      :longpoll ->
        Channel.longpoll_connected(pid, socket_pid, timeout)

      _ ->
        Logger.error(fn -> "Unknown channel kind #{inspect(kind)} for channel #{channel_ref}" end)
        :error
    end
  end
end
