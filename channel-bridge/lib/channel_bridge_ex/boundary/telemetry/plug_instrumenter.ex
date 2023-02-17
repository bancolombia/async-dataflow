defmodule ChannelBridgeEx.Boundary.Telemetry.PlugInstrumenter do
  @moduledoc false

  require Logger
  use Prometheus.Metric

  def setup do
    Counter.declare(
      name: :adfcb_plug_request_count,
      help: "Plug request Count"
    )

    events = [
      [:web, :plug, :start],
      [:web, :plug, :stop]
    ]

    :telemetry.attach_many("adf-bridge-plug", events, &handle_event/4, nil)
  end

  def handle_event([:web, :plug, :start], _measurements, _metadata, _config) do
    # Logger.info("Telemetry Received #{inspect(event)} event. measurements: #{inspect(measurements)}")
    Counter.inc(name: :adfcb_plug_request_count)
  end

  def handle_event([:web, :plug, :stop], _measurements, _metadata, _config) do
    # Logger.info("Telemetry Received #{inspect(event)} event. measurements: #{inspect(measurements)}")
    # Counter.inc(name: :adfcb_channel_total, labels: [metadata])
    :ok
  end
end
