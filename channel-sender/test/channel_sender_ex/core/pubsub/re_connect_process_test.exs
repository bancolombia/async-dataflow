defmodule ChannelSenderEx.Core.PubSub.ReConnectProcessTest do
  use ExUnit.Case

  alias ChannelSenderEx.Core.Channel
  alias ChannelSenderEx.Core.ChannelSupervisor
  alias ChannelSenderEx.Core.PubSub.ReConnectProcess
  import Mock

  setup do
    Application.put_env(:channel_sender_ex, :on_connected_channel_reply_timeout, 100)

    on_exit(fn ->
      Application.delete_env(:channel_sender_ex, :on_connected_channel_reply_timeout)
    end)
  end

  test "should not connect processes, due to process not registered" do
    with_mock(
      ChannelSupervisor, [whereis_channel: fn(_) -> :undefined end]
    ) do
      assert ReConnectProcess.connect_socket_to_channel("channel_ref", :c.pid(0, 250, 0), :websocket) == :noproc
    end
  end

  test "should query and connect processes" do
    with_mocks([
      {ChannelSupervisor, [], [whereis_channel: fn(_) -> :c.pid(0, 200, 0) end]},
      {Channel, [], [socket_connected: fn(_, _, _) -> :ok end]},
    ]) do
      assert is_pid(ReConnectProcess.connect_socket_to_channel("channel_ref", :c.pid(0, 250, 0), :websocket))
    end
  end

end
