defmodule ChannelBridgeEx.Entrypoint.Rest.Health.ProbeTest do
  use ExUnit.Case

  alias ChannelBridgeEx.Entrypoint.Rest.Health.Probe

  @moduletag :capture_log

  test "Should validate linevess" do
    assert :ok == Probe.liveness()
  end

  test "Should validate readiness" do
    assert :ok == Probe.readiness()
  end

end
