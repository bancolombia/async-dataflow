defmodule ChannelBridgeEx.Boundary.Telemetry.SenderInstrumenterTest do
  use ExUnit.Case

  alias Prometheus.Metric.Counter
  alias ChannelBridgeEx.Boundary.Telemetry.SenderInstrumenter

  import Mock

  @moduletag :capture_log

  test "Should collect metrics" do
    with_mocks([
      {Counter, [], [inc: fn _a -> :ok end]}
    ]) do
      SenderInstrumenter.handle_event([:adf, :sender, :message, :start], %{}, %{}, %{})
      SenderInstrumenter.handle_event([:adf, :sender, :message, :stop], %{}, %{}, %{})
      SenderInstrumenter.handle_event([:adf, :sender, :message, :exception], %{}, %{}, %{})
      SenderInstrumenter.handle_event([:adf, :sender, :channel, :stop], %{}, %{}, %{})
      SenderInstrumenter.handle_event([:adf, :sender, :channel, :exception], %{}, %{}, %{})
    end
  end
end
