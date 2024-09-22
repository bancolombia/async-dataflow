defmodule StreamsCore.CloudEvent.RoutingErrorTest do
  use ExUnit.Case

  alias StreamsCore.CloudEvent.RoutingError

  @moduletag :capture_log

  test "Should extract channel alias from data" do

    assert_raise RoutingError, fn ->
      raise RoutingError, message: "dummy reason"
    end

  end

end
