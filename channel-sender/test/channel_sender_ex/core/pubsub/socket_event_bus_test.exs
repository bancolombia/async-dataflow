defmodule ChannelSenderEx.Core.PubSub.SocketEventBusTest do
  use ExUnit.Case

  alias ChannelSenderEx.Core.Channel
  alias ChannelSenderEx.Core.ChannelSupervisor
  alias ChannelSenderEx.Core.PubSub.SocketEventBus

  import Mock

  test "Should retry n times" do
    channel = "some_channel"
    socket_pid = self()

    with_mock ChannelSupervisor, [whereis_channel: fn(_) -> :undefined end] do
      assert_raise RuntimeError, "No channel found", fn -> SocketEventBus.notify_event({:connected, channel, :websocket}, socket_pid) end
    end
  end

  test "Should not retry n times" do
    channel = "some_channel"
    pid = :c.pid(0, 250, 0)
    socket_pid = self()

    with_mocks([
      {ChannelSupervisor, [], [whereis_channel: fn(_) -> pid end]},
      {Channel, [], [socket_connected: fn(_, _, _) -> :ok end]}
      ]) do
      assert SocketEventBus.notify_event({:connected, channel, :websocket}, socket_pid) == pid
    end
  end

end
