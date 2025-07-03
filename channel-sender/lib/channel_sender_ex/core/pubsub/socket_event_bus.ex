defmodule ChannelSenderEx.Core.PubSub.SocketEventBus do
  @moduledoc """
  Handles different socket events, as connected and disconnected, and abstracts in some way the socket/channel discovery and
  association.
  """
  alias ChannelSenderEx.Core.Channel
  alias ChannelSenderEx.Core.ChannelSupervisor

  # Notify the event of a socket connection. Receiving part is the channel process.
  def notify_event({:connected, channel, kind}, socket_pid) when is_binary(channel) do
    connect_channel(channel, socket_pid, kind)
  end

  def notify_event({:connected, channel_pid, kind}, socket_pid) when is_pid(channel_pid) do
    timeout = Application.get_env(:channel_sender_ex, :on_connected_channel_reply_timeout)

    case kind do
      :sse ->
        :ok = Channel.sse_connected(channel_pid, socket_pid, timeout)

      :websocket ->
        :ok = Channel.socket_connected(channel_pid, socket_pid, timeout)

      :longpoll ->
        :ok = Channel.socket_connected(channel_pid, socket_pid, timeout)
    end

    channel_pid
  end

  def connect_channel(_, _, _, count \\ 0)
  def connect_channel(_, _, _, 7), do: raise("No channel found")

  def connect_channel(channel, socket_pid, kind, count) do
    case ChannelSupervisor.whereis_channel(channel) do
      :undefined ->
        Process.sleep(350)
        connect_channel(channel, socket_pid, kind, count + 1)

      pid when is_pid(pid) ->
        timeout = Application.get_env(:channel_sender_ex, :on_connected_channel_reply_timeout)

        case kind do
          :sse ->
            :ok = Channel.sse_connected(pid, socket_pid, timeout)

          :websocket ->
            :ok = Channel.socket_connected(pid, socket_pid, timeout)

          :longpoll ->
            :ok = Channel.longpoll_connected(pid, socket_pid, timeout)
        end

        pid
    end
  end
end
