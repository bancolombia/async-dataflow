defmodule ChannelBridgeEx.Boundary.Telemetry.ChannelInstrumenterTest do
  use ExUnit.Case

  alias Prometheus.Metric.Counter
  alias ChannelBridgeEx.Boundary.Telemetry.ChannelInstrumenter

  import Mock

  @moduletag :capture_log

  test "Should collect metrics" do
    with_mocks([
      {Counter, [], [inc: fn _a -> :ok end]}
    ]) do
      ChannelInstrumenter.handle_event([:adf, :channel, :missing], %{}, %{}, %{})
    end
  end
end
