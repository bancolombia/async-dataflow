defmodule BridgeCore.Boundary.NodeObserverTest do
  use ExUnit.Case

  import Mock

  alias BridgeCore.Boundary.NodeObserver

  test "Should start nodeobserver" do
    NodeObserver.start_link(nil)
  end

end
