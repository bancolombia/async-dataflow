defmodule ChannelSenderEx.Utils.CustomTelemetry do
  @moduledoc false

  import Telemetry.Metrics
  require OpenTelemetry.Tracer, as: Tracer
  alias ChannelSenderEx.Utils.CustomTelemetry, as: CT

  @service_name "channel_sender_ex"

  def custom_telemetry_events do
    :telemetry.attach(
      "channel_sender_ex-plug-stop",
      [:channel_sender_ex, :plug, :stop],
      &CT.handle_custom_event/4,
      nil
    )

    :telemetry.attach(
      "cowboy-telemetry-logger",
      [:cowboy, :request, :stop],
      &CT.handle_custom_event/4,
      nil
    )

    :telemetry.attach("vm-memory", [:vm, :memory], &CT.handle_custom_event/4, nil)

    :telemetry.attach(
      "vm-total_run_queue_lengths",
      [:vm, :total_run_queue_lengths],
      &CT.handle_custom_event/4,
      nil
    )

    :telemetry.attach(
      "adf-message-delivered",
      [:adf, :message, :delivered],
      &CT.handle_custom_event/4,
      nil
    )

    :telemetry.attach(
      "adf-message-nodelivered",
      [:adf, :message, :nodelivered],
      &CT.handle_custom_event/4,
      nil
    )

    :telemetry.attach(
      "adf-socket-failure",
      [:adf, :socket, :failure],
      &CT.handle_custom_event/4,
      nil
    )
  end

  def execute_custom_event(metric, value, metadata \\ %{}) when is_list(metric) do
    metadata = Map.put(metadata, :service, @service_name)
    :telemetry.execute([:elixir | metric], value, metadata)
  end

  # def execute_custom_event(metric, value, metadata) when is_atom(metric) do
  #   execute_custom_event([metric], value, metadata)
  # end

  def handle_custom_event([:channel_sender_ex, :plug, :stop], measures, metadata, _) do
    :telemetry.execute(
      [:elixir, :http_request_duration_milliseconds],
      %{duration: monotonic_time_to_milliseconds(measures.duration)},
      %{
        request_path: metadata.conn.request_path,
        status: metadata.conn.status,
        service: @service_name
      }
    )
  end

  def handle_custom_event(metric, measures, metadata, _) do
    metadata = Map.put(metadata, :service, @service_name)
    :telemetry.execute([:elixir | metric], measures, metadata)
  end

  def metrics do
    [
      # Plug Metrics
      counter("elixir.http_request_duration_milliseconds.count",
        tags: [:request_path, :status, :service]
      ),
      sum("elixir.http_request_duration_milliseconds.duration",
        tags: [:request_path, :status, :service]
      ),

      # Custom Metrics
      counter("elixir.adf.message.delivered.count", tags: [:service]),
      counter("elixir.adf.message.nodelivered.count", tags: [:service]),
      counter("elixir.adf.socket.badrequest.count",
        tags: [:request_path, :status, :code, :service]
      ),
      counter("elixir.adf.socket.switchprotocol.count",
        tags: [:request_path, :status, :code, :service]
      ),
      counter("elixir.adf.socket.connection.count", tags: [:service]),
      counter("elixir.adf.socket.disconnection.count", tags: [:service]),
      counter("elixir.adf.socket_duration_milliseconds.count", tags: [:request_path, :service]),
      counter("elixir.adf.channel.created.count", tags: [:service]),
      counter("elixir.adf.channel.deleted.count", tags: [:service]),
      counter("elixir.adf.sse.connection.count", tags: [:service]),
      counter("elixir.adf.sse.badrequest.count", tags: [:status, :code, :service]),
      sum("elixir.adf.channel.created_on_socket.count",
        tags: [:service],
        reporter_options: [report_as: :counter]
      ),
      sum("elixir.adf.channel.pending.send.count",
        tags: [:service],
        reporter_options: [report_as: :counter]
      ),
      sum("elixir.adf.channel.pending.ack.count",
        tags: [:service],
        reporter_options: [report_as: :counter]
      ),

      # VM Metrics
      last_value("elixir.vm.memory.total", unit: {:byte, :kilobyte}, tags: [:service]),
      last_value("elixir.vm.memory.processes", unit: {:byte, :kilobyte}, tags: [:service]),
      last_value("elixir.vm.memory.binary", unit: {:byte, :kilobyte}, tags: [:service]),
      last_value("elixir.vm.memory.ets", unit: {:byte, :kilobyte}, tags: [:service]),
      last_value("elixir.vm.total_run_queue_lengths.total", tags: [:service]),
      last_value("elixir.vm.total_run_queue_lengths.cpu", tags: [:service]),
      last_value("elixir.vm.total_run_queue_lengths.io", tags: [:service])
    ]
  end

  # Traces
  def start_span(protocol, req, channel) do
    traces_enable = Application.get_env(:channel_sender_ex, :traces_enable, false)

    if traces_enable do
      span_name = "#{req.path}->#{channel}"

      {peer_ip, peer_port} = req.peer

      attributes =
        [
          "http.target": req.path,
          "http.host": req.host,
          "http.scheme": req.scheme,
          "http.flavor": map_http_version(req.version),
          "http.method": req.method,
          "net.peer.ip": to_string(:inet_parse.ntoa(peer_ip)),
          "net.peer.port": peer_port,
          "net.host.port": req.port,
          "adf.channel_ref": channel,
          "adf.protocol": protocol
        ]

      Tracer.start_span(span_name, %{attributes: attributes, kind: :server})
    end
  end

  def end_span(cause) do
    Tracer.set_attribute("adf.socket.close_reason", cause)
    Tracer.end_span()
  end

  defp monotonic_time_to_milliseconds(monotonic_time) do
    monotonic_time |> System.convert_time_unit(:native, :millisecond)
  end

  defp map_http_version(:"HTTP/1.0"), do: :"1.0"
  defp map_http_version(:"HTTP/1"), do: :"1.0"
  defp map_http_version(:"HTTP/1.1"), do: :"1.1"
  defp map_http_version(:"HTTP/2.0"), do: :"2.0"
  defp map_http_version(:"HTTP/2"), do: :"2.0"
  defp map_http_version(:"HTTP/3.0"), do: :"3.0"
  defp map_http_version(:"HTTP/3"), do: :"3.0"
  defp map_http_version(:SPDY), do: :SPDY
  defp map_http_version(:QUIC), do: :QUIC
  defp map_http_version(_other), do: ""
end
