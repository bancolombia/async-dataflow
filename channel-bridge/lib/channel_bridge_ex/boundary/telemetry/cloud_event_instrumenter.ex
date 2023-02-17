defmodule ChannelBridgeEx.Boundary.Telemetry.CloudEventInstrumenter do
  @moduledoc false

  require Logger
  use Prometheus.Metric

  def setup do
    Counter.declare(
      name: :adfcb_cloudevent_parse_count,
      help: "CloudEvent Messages parse count"
    )

    Counter.declare(
      name: :adfcb_cloudevent_parse_fail_count,
      help: "CloudEvent Messages Failed to parse count"
    )

    Counter.declare(
      name: :adfcb_cloudevent_failed_mutations_count,
      help: "CloudEvent Messages Failed Mutations Count"
    )

    events = [
      [:adf, :cloudevent, :parsing, :start],
      [:adf, :cloudevent, :parsing, :stop],
      [:adf, :cloudevent, :parsing, :exception],
      [:adf, :cloudevent, :mutations, :exception]
    ]

    :telemetry.attach_many("adf-bridge-cloud-events", events, &handle_event/4, nil)
  end

  def handle_event([:adf, :cloudevent, :parsing, :start], _measurements, _metadata, _config) do
    # Counter.inc(name: :adfcb_sender_messages_count)
    :ok
  end

  def handle_event([:adf, :cloudevent, :parsing, :stop], _measurements, _metadata, _config) do
    Counter.inc(name: :adfcb_cloudevent_parse_count)
  end

  def handle_event([:adf, :cloudevent, :parsing, :exception], _measurements, _metadata, _config) do
    Counter.inc(name: :adfcb_cloudevent_parse_fail_count)
  end

  def handle_event([:adf, :cloudevent, :mutations, :exception], _measurements, _metadata, _config) do
    Counter.inc(name: :adfcb_cloudevent_failed_mutations_count)
  end
end
