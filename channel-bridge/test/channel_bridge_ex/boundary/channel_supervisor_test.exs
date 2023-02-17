defmodule ChannelBridgeEx.Boundary.ChannelSupervisorTest do
  use ExUnit.Case

  import Mock

  alias ChannelBridgeEx.Core.Channel
  alias ChannelBridgeEx.Boundary.ChannelSupervisor
  alias Horde.DynamicSupervisor

  setup_with_mocks([
    {DynamicSupervisor, [], [start_child: fn _module, _child -> :ok end]}
  ]) do
    :ok
  end

  test "Should start channel" do
    channel = Channel.new("my-alias", "app01", "user1")
    pid = ChannelSupervisor.start_channel_process(channel)
    assert pid != nil
  end
end
