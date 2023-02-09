defmodule ChannelBridgeEx.Boundary.Telemetry.BroadwayInstrumenter do
  @moduledoc false

  require Logger
  use Prometheus.Metric

  def setup do
    Counter.declare(
      name: :adfcb_broadway_msg_count,
      help: "Broadway messages Count"
    )

    Counter.declare(
      name: :adfcb_broadway_err_count,
      help: "Broadway errors Count"
    )

    events = [
      [:broadway, :processor, :message, :start],
      [:broadway, :processor, :message, :stop],
      [:broadway, :processor, :message, :exception]
    ]

    :telemetry.attach_many("adf-bridge-broadway", events, &handle_event/4, nil)
  end

  def handle_event([:broadway, :processor, :message, :start], _measurements, _metadata, _config) do
    # Counter.inc(name: :adfcb_plug_request_count)
    :ok
  end

  def handle_event([:broadway, :processor, :message, :stop], _measurements, _metadata, _config) do
    Counter.inc(name: :adfcb_broadway_msg_count)
  end

  def handle_event(
        [:broadway, :processor, :message, :exception],
        _measurements,
        _metadata,
        _config
      ) do
    Counter.inc(name: :adfcb_broadway_err_count)
  end
end
