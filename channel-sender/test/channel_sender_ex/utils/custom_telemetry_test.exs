defmodule ChannelSenderEx.Utils.CustomTelemetryTest do
  alias ChannelSenderEx.Utils.CustomTelemetry
  use ExUnit.Case

  setup_all do
    {:ok, _} = Application.ensure_all_started(:telemetry_metrics_prometheus)
    :ok
  end

  test "Should send metrics" do
    CustomTelemetry.handle_custom_event([:channel_sender_ex, :plug, :stop],
      %{:duration => 10}, %{:conn => %{:request_path => "test", status: 200}}, %{})
    assert true
  end

  test "Should send custom metrics" do
    CustomTelemetry.execute_custom_event([:test], 10 - 1, %{})
    assert true
  end

  test "Should send custom metrics II" do
    CustomTelemetry.handle_custom_event([:test], %{:duration => 10},
      %{:conn => %{:request_path => "test", status: 200}}, %{})
    assert true
  end

  test "set metrics" do
    CustomTelemetry.metrics()
    assert true
  end

  test "set events" do
    CustomTelemetry.custom_telemetry_events()
    assert true
  end

end
