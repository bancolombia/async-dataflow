defmodule StreamsCore.Boundary.ChannelSupervisorTest do
  use ExUnit.Case

  import Mock

  alias StreamsCore.Channel

  alias StreamsCore.Boundary.ChannelManager
  alias StreamsCore.Boundary.ChannelSupervisor

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
        StreamsCore.CloudEvent.Mutator.DefaultMutator)
      assert pid != nil
    end
  end

  test "Should handle starting channel more than once" do
    with_mocks([
      {DynamicSupervisor, [], [
        start_child: fn _module, _child -> {:error, {:already_started, self()}} end
      ]},
      {ChannelManager, [], [
        update: fn _pid, _channel -> :ok end
      ]},

    ]) do

      channel = Channel.new("my-alias0980978", "app01", "user1")
      pid = ChannelSupervisor.start_channel_process(channel,
        StreamsCore.CloudEvent.Mutator.DefaultMutator)
      assert pid != nil

    end
  end
end
