defmodule ChannelBridgeEx.Boundary.Telemetry.SenderInstrumenter do
  @moduledoc false

  require Logger
  use Prometheus.Metric

  def setup do
    Counter.declare(
      name: :adfcb_sender_delivery_count,
      help: "Messages delivered to ADF Sender"
    )

    Counter.declare(
      name: :adfcb_sender_delivery_fail_count,
      help: "Messages failed delivery to ADF Sender"
    )

    Counter.declare(
      name: :adfcb_sender_request_channel_count,
      help: "Channel requested to ADF sender"
    )

    Counter.declare(
      name: :adfcb_sender_request_channel_fail_count,
      help: "Channel failures requested to ADF sender"
    )

    events = [
      [:adf, :sender, :message, :start],
      [:adf, :sender, :message, :stop],
      [:adf, :sender, :message, :exception],
      [:adf, :sender, :channel, :start],
      [:adf, :sender, :channel, :stop],
      [:adf, :sender, :channel, :exception]
    ]

    :telemetry.attach_many("adf-bridge-sender", events, &handle_event/4, nil)
  end

  def handle_event([:adf, :sender, :message, :start], _measurements, _metadata, _config) do
    :ok
  end

  def handle_event([:adf, :sender, :message, :stop], _measurements, _metadata, _config) do
    Counter.inc(name: :adfcb_sender_delivery_count)
  end

  def handle_event([:adf, :sender, :message, :exception], _measurements, _metadata, _config) do
    Counter.inc(name: :adfcb_sender_delivery_fail_count)
  end

  def handle_event([:adf, :sender, :channel, :start], _measurements, _metadata, _config) do
    :ok
  end

  def handle_event([:adf, :sender, :channel, :stop], _measurements, _metadata, _config) do
    Counter.inc(name: :adfcb_sender_request_channel_count)
  end

  def handle_event([:adf, :sender, :channel, :exception], _measurements, _metadata, _config) do
    Counter.inc(name: :adfcb_sender_request_channel_fail_count)
  end
end
