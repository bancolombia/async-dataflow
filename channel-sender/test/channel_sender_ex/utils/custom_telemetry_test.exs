defmodule ChannelSenderEx.Utils.CustomTelemetryTest do
  alias ChannelSenderEx.Utils.CustomTelemetry
  use ExUnit.Case

  setup_all do
    {:ok, _} = Application.ensure_all_started(:telemetry_metrics_prometheus)
    :ok
  end

  test "Should send metrics" do
    CustomTelemetry.handle_custom_event(
      [:channel_sender_ex, :plug, :stop],
      %{:duration => 10},
      %{:conn => %{:request_path => "test", status: 200}},
      %{}
    )

    assert true
  end

  test "Should send custom metrics" do
    CustomTelemetry.execute_custom_event([:test], 10 - 1, %{})
    assert true
  end

  test "Should send custom metrics II" do
    CustomTelemetry.handle_custom_event(
      [:test],
      %{:duration => 10},
      %{:conn => %{:request_path => "test", status: 200}},
      %{}
    )

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

  describe "span traces test" do
    test "start span with various HTTP versions enable" do
      Application.put_env(:channel_sender_ex, :traces_enable, true)

      http_versions = [
        {:"HTTP/1.0", :"1.0"},
        {:"HTTP/1", :"1.0"},
        {:"HTTP/1.1", :"1.1"},
        {:"HTTP/2.0", :"2.0"},
        {:"HTTP/2", :"2.0"},
        {:"HTTP/3.0", :"3.0"},
        {:"HTTP/3", :"3.0"},
        {:SPDY, :SPDY},
        {:QUIC, :QUIC},
        {:UNKNOWN, ""}
      ]

      Enum.each(http_versions, fn {input_version, _expected} ->
        req = %{
          :path => "/test",
          :host => "localhost",
          :scheme => "http",
          :version => input_version,
          :method => "GET",
          :peer => {{127, 0, 0, 1}, 4000},
          :port => 8080
        }

        case CustomTelemetry.start_span(:test, req, "ch_123") do
          {:span_ctx, _, _, _, _, _, _, _, _, _, _} ->
            assert true

          other ->
            flunk(
              "Unexpected return value for version #{inspect(input_version)}: #{inspect(other)}"
            )
        end
      end)
    end

    test "start span with various HTTP versions disable" do
      Application.put_env(:channel_sender_ex, :traces_enable, false)
      CustomTelemetry.start_span(:test, %{}, "ch_123")
      assert true
    end

    test "end span with cause" do
      CustomTelemetry.end_span("normal")
      assert true
    end
  end
end
