defmodule ChannelSenderEx.Core.PubSub.SocketEventBus do
  @moduledoc """
  Handles different socket events, as connected and disconnected, and abstracts in some way the socket/channel discovery and
  association.
  """

  def notify_event({:connected, _channel, _app, _user}, _socket_pid) do
  end
end
