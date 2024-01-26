defmodule BridgeCore.Boundary.NodeObserverTest do
  use ExUnit.Case

  import Mock

  alias BridgeCore.Boundary.NodeObserver
  alias BridgeCore.Boundary.ChannelRegistry
  alias BridgeCore.Boundary.ChannelSupervisor

  test "Should start nodeobserver" do
    {:ok, rpid} = ChannelRegistry.start_link(nil)
    {:ok, spid} = ChannelSupervisor.start_link(nil)

    {:ok, pid} = NodeObserver.start_link(nil)
    assert is_pid(pid)

    assert {:noreply, nil} == NodeObserver.handle_info({:nodeup, nil, nil}, nil)
    assert {:noreply, nil} == NodeObserver.handle_info({:nodedown, nil, nil}, nil)

  end

end
