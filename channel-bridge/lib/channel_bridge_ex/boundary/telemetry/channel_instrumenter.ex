defmodule ChannelBridgeEx.Boundary.Telemetry.ChannelInstrumenter do
  @moduledoc false

  require Logger
  use Prometheus.Metric

  def setup do
    Counter.declare(
      name: :adfcb_channel_noproc_count,
      help: "Channel process lookup failed"
    )

    Counter.declare(
      name: :adfcb_channel_alias_missing,
      help: "Channel info not present in event data"
    )

    events = [
      [:adf, :channel, :missing],
      [:adf, :channel, :alias_missing]
    ]

    :telemetry.attach_many("adf-bridge-channel", events, &handle_event/4, nil)
  end

  def handle_event([:adf, :channel, :missing], _measurements, _metadata, _config) do
    Counter.inc(name: :adfcb_channel_noproc_count)
  end

  def handle_event([:adf, :channel, :alias_missing], _measurements, _metadata, _config) do
    Counter.inc(name: :adfcb_channel_alias_missing)
  end
end
