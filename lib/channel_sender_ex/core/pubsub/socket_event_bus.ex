defmodule ChannelSenderEx.Core.PubSub.SocketEventBus do
  @moduledoc """
  Handles different socket events, as connected and disconnected, and abstracts in some way the socket/channel discovery and
  association.
  """
  alias ChannelSenderEx.Core.ChannelRegistry
  alias ChannelSenderEx.Core.Channel

  def notify_event({:connected, channel}, socket_pid) do
    channel_addr = ChannelRegistry.lookup_channel_addr(channel)
    :ok = Channel.socket_connected(channel_addr, socket_pid)
  end
end
