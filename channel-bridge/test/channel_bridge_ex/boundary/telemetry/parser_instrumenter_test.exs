defmodule ChannelBridgeEx.Boundary.Telemetry.CloudEventInstrumenterTest do
  use ExUnit.Case

  alias Prometheus.Metric.Counter
  alias ChannelBridgeEx.Boundary.Telemetry.CloudEventInstrumenter

  import Mock

  @moduletag :capture_log

  test "Should collect metrics" do
    with_mocks([
      {Counter, [], [inc: fn _a -> :ok end]}
    ]) do
      CloudEventInstrumenter.handle_event([:adf, :cloudevent, :parsing, :start], %{}, %{}, %{})
      CloudEventInstrumenter.handle_event([:adf, :cloudevent, :parsing, :stop], %{}, %{}, %{})

      CloudEventInstrumenter.handle_event(
        [:adf, :cloudevent, :parsing, :exception],
        %{},
        %{},
        %{}
      )
    end
  end
end
