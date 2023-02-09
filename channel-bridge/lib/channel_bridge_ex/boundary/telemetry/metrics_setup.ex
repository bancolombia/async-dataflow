defmodule ChannelBridgeEx.Boundary.Telemetry.MetricsSetup do
  @moduledoc false

  alias ChannelBridgeEx.Boundary.Telemetry.PlugInstrumenter
  alias ChannelBridgeEx.Entrypoint.Rest.PrometheusExporter
  alias ChannelBridgeEx.Boundary.Telemetry.BroadwayInstrumenter
  alias ChannelBridgeEx.Boundary.Telemetry.SenderInstrumenter
  alias ChannelBridgeEx.Boundary.Telemetry.ChannelInstrumenter
  alias ChannelBridgeEx.Boundary.Telemetry.CloudEventInstrumenter

  def setup do
    PlugInstrumenter.setup()
    BroadwayInstrumenter.setup()
    SenderInstrumenter.setup()
    ChannelInstrumenter.setup()
    CloudEventInstrumenter.setup()
    PrometheusExporter.setup()
  end
end
