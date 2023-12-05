defmodule BridgeCore.Boundary.ChannelSupervisorTest do
  use ExUnit.Case

  import Mock

  alias BridgeCore.Channel
  alias BridgeCore.Boundary.ChannelSupervisor
  alias Horde.DynamicSupervisor

  test "Should start supervisor" do
    ChannelSupervisor.start_link(nil)
  end

  test "Should start channel" do
    with_mocks([
      {DynamicSupervisor, [], [
        start_child: fn _module, _child -> :ok end
      ]}
    ]) do

      channel = Channel.new("my-alias", "app01", "user1")
      pid = ChannelSupervisor.start_channel_process(channel,
        BridgeCore.CloudEvent.Mutator.DefaultMutator)
      assert pid != nil

    end
  end
end
