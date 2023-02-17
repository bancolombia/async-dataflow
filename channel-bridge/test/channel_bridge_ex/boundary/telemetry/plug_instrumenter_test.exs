defmodule ChannelBridgeEx.Boundary.Telemetry.PlugInstrumenterTest do
  use ExUnit.Case

  alias Prometheus.Metric.Counter
  alias ChannelBridgeEx.Boundary.Telemetry.PlugInstrumenter

  import Mock

  @moduletag :capture_log

  test "Should collect metrics" do
    with_mocks([
      {Counter, [], [inc: fn _a -> :ok end]}
    ]) do
      PlugInstrumenter.handle_event([:web, :plug, :start], %{}, %{}, %{})
      PlugInstrumenter.handle_event([:web, :plug, :stop], %{}, %{}, %{})
    end
  end
end
