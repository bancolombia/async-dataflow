defmodule ChannelSenderEx.Core.PubSub.SocketEventBus do
  @moduledoc """
  Handles different socket events, as connected and disconnected, and abstracts in some way the socket/channel discovery and
  association.
  """
  alias ChannelSenderEx.Core.Channel
  alias ChannelSenderEx.Core.ChannelRegistry

  # Notify the event of a socket connection. Receiving part is the channel process.
  def notify_event({:connected, channel}, socket_pid) do
    connect_channel(channel, socket_pid)
  end

  # Notify the event with the reason of a socket disconnection. Receiving part is
  # the channel process. This will be used to determine the time the process
  # will be waiting for the socket re-connection. Depending on configuration the
  # waiting time may actually be zero and the process then shuts down inmediately.
  # See config element: `channel_shutdown_socket_disconnect`
  def notify_event({:socket_down_reason, channel_ref, reason}, _socket_pid) do
    socket_disconnect_reason(channel_ref, reason)
  end

  def connect_channel(_, _, count \\ 0)
  def connect_channel(_, _, 7), do: raise("No channel found")

  def connect_channel(channel, socket_pid, count) do
    case ChannelRegistry.lookup_channel_addr(channel) do
      pid when is_pid(pid) ->
        timeout = Application.get_env(:channel_sender_ex,
                            :on_connected_channel_reply_timeout)
        :ok = Channel.socket_connected(pid, socket_pid, timeout)
        pid
      :noproc ->
        Process.sleep(350)
        connect_channel(channel, socket_pid, count + 1)
    end
  end

  defp socket_disconnect_reason(channel, reason) do
    case look_channel(channel) do
      pid when is_pid(pid) ->
        Channel.socket_disconnect_reason(pid, reason)
      :noproc -> :noproc
    end
  end

  defp look_channel(channel) do
    case ChannelRegistry.lookup_channel_addr(channel) do
      pid when is_pid(pid) -> pid
      :noproc -> :noproc
    end
  end
end
