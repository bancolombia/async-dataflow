defmodule ChannelSenderEx.Core.PubSub.SocketEventBus do
  @moduledoc """
  Handles different socket events, as connected and disconnected, and abstracts in some way the socket/channel discovery and
  association.
  """
  alias ChannelSenderEx.Core.Channel
  alias ChannelSenderEx.Core.ChannelSupervisorPg, as: ChannelSupervisor

  # Notify the event of a socket connection. Receiving part is the channel process.
  def notify_event({:connected, channel}, socket_pid) when is_binary(channel) do
    connect_channel(channel, socket_pid)
  end

  def notify_event({:connected, channel_pid}, socket_pid) when is_pid(channel_pid) do
    timeout = Application.get_env(:channel_sender_ex, :on_connected_channel_reply_timeout)
    :ok = Channel.socket_connected(channel_pid, socket_pid, timeout)
    channel_pid
  end

  def connect_channel(_, _, count \\ 0)
  def connect_channel(_, _, 7), do: raise("No channel found")

  def connect_channel(channel, socket_pid, count) do
    case ChannelSupervisor.whereis_channel(channel) do
      :undefined ->
        Process.sleep(350)
        connect_channel(channel, socket_pid, count + 1)
      pid when is_pid(pid) ->
        timeout = Application.get_env(:channel_sender_ex, :on_connected_channel_reply_timeout)
        :ok = Channel.socket_connected(pid, socket_pid, timeout)
        pid
    end
  end

end
