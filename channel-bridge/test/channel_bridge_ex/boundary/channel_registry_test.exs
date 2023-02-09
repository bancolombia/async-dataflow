defmodule ChannelBridgeEx.Boundary.ChannelRegistryTest do
  use ExUnit.Case

  import Mock

  alias ChannelBridgeEx.Boundary.ChannelRegistry
  alias Horde.Registry

  test "Should lookup channel" do
    with_mocks([
      {Registry, [], [lookup: fn _ref -> [{:c.pid(0, 250, 0), "xx"}] end]}
    ]) do
      pid = ChannelRegistry.lookup_channel_addr("A")
      assert pid != nil
      # assert Process.info(pid, :priority) == {:priority, :normal}
    end
  end

  test "Should not lookup channel" do
    with_mocks([
      {Registry, [], [lookup: fn _ref -> [] end]}
    ]) do
      nopid = ChannelRegistry.lookup_channel_addr("B")
      assert nopid == :noproc
    end
  end
end
