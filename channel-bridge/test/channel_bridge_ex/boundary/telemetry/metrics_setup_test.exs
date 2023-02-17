defmodule ChannelBridgeEx.Boundary.Telemetry.MetricsSetupTest do
  use ExUnit.Case

  alias Prometheus.Metric.Counter
  alias Prometheus.Metric.Summary
  alias ChannelBridgeEx.Boundary.Telemetry.MetricsSetup

  import Mock

  @moduletag :capture_log

  test "Should setup metrics" do
    with_mocks([
      {Counter, [],
       [
         declare: fn _a -> :ok end,
         inc: fn _a, _b -> :ok end
       ]},
      {Summary, [], [declare: fn _a -> :ok end]},
      {:telemetry, [], [attach_many: fn _a, _b, _c, _d -> :ok end]}
    ]) do
      MetricsSetup.setup()
    end
  end
end
