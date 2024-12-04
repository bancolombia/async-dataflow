defmodule ChannelSenderEx.Core.PubSub.SocketEventBusTest do
  use ExUnit.Case

  alias ChannelSenderEx.Core.PubSub.SocketEventBus
  alias ChannelSenderEx.Core.RulesProvider.Helper

  @moduletag :capture_log

  test "Should fail on max conns" do
    assert_raise(RuntimeError, "No channel found", fn -> SocketEventBus.connect_channel("", :c.pid(0, 250, 0), 7) end)
  end

end
