defmodule ChannelBridgeEx.Boundary.Telemetry.BroadwayInstrumenterTest do
  use ExUnit.Case

  alias Prometheus.Metric.Counter
  alias ChannelBridgeEx.Boundary.Telemetry.BroadwayInstrumenter

  import Mock

  @moduletag :capture_log

  test "Should collect metrics" do
    with_mocks([
      {Counter, [], [inc: fn _a -> :ok end]}
    ]) do
      BroadwayInstrumenter.handle_event([:broadway, :processor, :message, :start], %{}, %{}, %{})
      BroadwayInstrumenter.handle_event([:broadway, :processor, :message, :stop], %{}, %{}, %{})

      BroadwayInstrumenter.handle_event(
        [:broadway, :processor, :message, :exception],
        %{},
        %{},
        %{}
      )
    end
  end
end
