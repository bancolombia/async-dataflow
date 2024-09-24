defmodule StreamsCore.Boundary.NodeObserverTest do
  use ExUnit.Case

  alias StreamsCore.Boundary.{ChannelRegistry, ChannelSupervisor, NodeObserver}

   setup do
     {:ok, rpid} = ChannelRegistry.start_link(nil)
     {:ok, spid} = ChannelSupervisor.start_link(nil)

     on_exit(fn ->
       Process.exit(rpid, :kill)
       Process.exit(spid, :kill)
     end)

     :ok
   end

  test "Should start nodeobserver" do
    {:ok, pid} = NodeObserver.start_link(nil)
    assert is_pid(pid)

    assert {:noreply, nil} == NodeObserver.handle_info({:nodeup, nil, nil}, nil)
    assert {:noreply, nil} == NodeObserver.handle_info({:nodedown, nil, nil}, nil)

  end

end
