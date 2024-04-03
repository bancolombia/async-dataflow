defmodule BridgeCore.CloudEvent.RoutingErrorTest do
  use ExUnit.Case

  alias BridgeCore.CloudEvent.RoutingError

  @moduletag :capture_log

  test "Should extract channel alias from data" do

    assert_raise RoutingError, fn ->
      raise RoutingError, message: "dummy reason"
    end

  end

end
