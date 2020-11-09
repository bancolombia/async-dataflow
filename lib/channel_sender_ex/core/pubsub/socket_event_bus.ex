defmodule ChannelSenderEx.Core.PubSub.SocketEventBus do
  @moduledoc """
  Handles different socket events, as connected and disconnected, and abstracts in some way the socket/channel discovery and
  association.
  """
  alias ChannelSenderEx.Core.ChannelRegistry
  alias ChannelSenderEx.Core.Channel

  def notify_event({:connected, channel}, socket_pid) do
    connect_channel(channel, socket_pid)
  end

  def connect_channel(_, _, count \\ 0)
  def connect_channel(_, _, 7), do: raise "No channel found"
  def connect_channel(channel, socket_pid, count) do
    case ChannelRegistry.lookup_channel_addr(channel) do
      pid when is_pid(pid) ->
        :ok = Channel.socket_connected(pid, socket_pid)
      :noproc ->
        Process.sleep(350)
        connect_channel(channel, socket_pid, count + 1)
    end
  end

end
