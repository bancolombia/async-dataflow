defmodule ChannelSenderEx.Core.PubSub.ReConnectProcess do

  alias ChannelSenderEx.Core.{ChannelRegistry, Channel}
  import ChannelSenderEx.Core.Retry.ExponentialBackoff, only: [execute: 5]
  require Logger

  @max_retries 11
  @min_backoff 50
  @max_backoff 3000

  def start(socket_pid, channel_ref) do
    Logger.debug("Starting re-connection process for channel #{channel_ref}")
    action_function = create_action(channel_ref, socket_pid, Process.monitor(socket_pid))
    execute(@min_backoff, @max_backoff, @max_retries, action_function, :no_channel)
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
        result -> result
      end
    end
  end

  def connect_socket_to_channel(channel_ref, socket_pid) do
    case ChannelRegistry.lookup_channel_addr(channel_ref) do
      :noproc -> :noproc
      pid ->
        timeout = Application.get_env(:channel_sender_ex,
                            :on_connected_channel_reply_timeout)
        Channel.socket_connected(pid, socket_pid, timeout)
    end
  catch
    _type, _err -> :noproc
  end


end
