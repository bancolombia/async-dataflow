defmodule ChannelSenderEx.Core.PubSub.ReConnectProcess do
  @moduledoc false

  alias ChannelSenderEx.Core.Channel
  alias ChannelSenderEx.Core.ChannelSupervisor

  import ChannelSenderEx.Core.Retry.ExponentialBackoff, only: [execute: 5]
  require Logger

  @max_retries 11
  @min_backoff 50
  @max_backoff 3000

  def start(socket_pid, channel_ref) do
    Logger.debug("Starting re-connection process for channel #{channel_ref}")
    action_function = create_action(channel_ref, socket_pid, Process.monitor(socket_pid))

    execute(
      @min_backoff,
      @max_backoff,
      @max_retries,
      action_function,
      fn -> start_channel(channel_ref) end
    )
  end

  def create_action(channel_ref, socket_pid, socket_mon_ref) do
    fn actual_delay ->
      case connect_socket_to_channel(channel_ref, socket_pid) do
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

  def connect_socket_to_channel(channel_ref, socket_pid) do
    case ChannelSupervisor.whereis_channel(channel_ref) do
      :undefined ->
        :noproc

      pid when is_pid(pid) ->
        Logger.debug(fn -> "Connecting socket #{inspect(pid)} to channel #{channel_ref}" end)
        timeout = Application.get_env(:channel_sender_ex, :on_connected_channel_reply_timeout)
        Channel.socket_connected(pid, socket_pid, timeout)
        pid
    end
  catch
    _type, err ->
      Logger.error("Error connecting socket to channel #{inspect(err)}")
      :noproc
  end

  def start_channel(channel_ref) do
    case ChannelSupervisor.register_channel({channel_ref, "", "", []}) do
      {:ok, pid} ->
        Logger.debug(
          "Re-connection process for channel #{channel_ref} solved with new pid: #{inspect(pid)}"
        )

        pid

      other ->
        Logger.error("Re-connection process for channel #{channel_ref} failed: #{inspect(other)}")

        other
    end
  end
end
