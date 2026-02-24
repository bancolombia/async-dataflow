defmodule ChannelSenderEx.Utils.CustomTelemetry do
  @moduledoc false

  import Telemetry.Metrics
  require OpenTelemetry.Tracer, as: Tracer
  alias ChannelSenderEx.Utils.CustomTelemetry, as: CT

  alias OpenTelemetry.SemConv.{
    ClientAttributes,
    HTTPAttributes,
    NetworkAttributes,
    ServerAttributes,
    URLAttributes,
    UserAgentAttributes
  }

  @dialyzer {:nowarn_function, client_info: 3}
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
      last_value("elixir.vm.total_run_queue_lengths.io", tags: [:service]),
      last_value("elixir.adf.channel.active.count", tags: [:service])
    ]
  end

  # Traces
  def start_span(protocol, req, channel) do
    traces_enable = Application.get_env(:channel_sender_ex, :traces_enable, false)

    if traces_enable do
      span_name = "#{req.path}"

      {peer_ip, peer_port} = req.peer
      {local_ip, _} = req.sock
      peer_address = to_string(:inet_parse.ntoa(peer_ip))
      local_address = to_string(:inet_parse.ntoa(local_ip))

      {protocol_name, protocol_version} = map_http_version(req.version)
      {client_address, client_port} = client_info(req, peer_address, peer_port)

      attributes = %{
        ClientAttributes.client_port() => client_port,
        ClientAttributes.client_address() => client_address,
        HTTPAttributes.http_request_method() => req.method,
        HTTPAttributes.http_route() => req.path,
        NetworkAttributes.network_local_address() => local_address,
        NetworkAttributes.network_protocol_name() => protocol_name,
        NetworkAttributes.network_protocol_version() => protocol_version,
        NetworkAttributes.network_peer_address() => peer_address,
        NetworkAttributes.network_transport() => "tcp",
        ServerAttributes.server_address() => req.host,
        ServerAttributes.server_port() => req.port,
        URLAttributes.url_path() => req.path,
        URLAttributes.url_scheme() => req.scheme,
        :"adf.channel_ref" => channel,
        :"adf.protocol" => protocol
      }

      attributes =
        if Map.has_key?(req.headers, "user-agent") do
          Map.put(
            attributes,
            UserAgentAttributes.user_agent_original(),
            req.headers["user-agent"]
          )
        else
          attributes
        end

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

  defp client_info(req, peer_ip, peer_port) do
    case :otel_http.extract_client_info(req.headers) do
      %{ip: :undefined, port: :undefined} -> {peer_ip, peer_port}
      %{ip: ip, port: :undefined} -> {ip, peer_port}
      %{ip: :undefined, port: port} -> {peer_ip, port}
      %{ip: ip, port: port} -> {ip, port}
    end
  end

  defp map_http_version(:"HTTP/1.0"), do: {"http", :"1.0"}
  defp map_http_version(:"HTTP/1"), do: {"http", :"1.0"}
  defp map_http_version(:"HTTP/1.1"), do: {"http", :"1.1"}
  defp map_http_version(:"HTTP/2.0"), do: {"http", :"2.0"}
  defp map_http_version(:"HTTP/2"), do: {"http", :"2.0"}
  defp map_http_version(:"HTTP/3.0"), do: {"http", :"3.0"}
  defp map_http_version(:"HTTP/3"), do: {"http", :"3.0"}
  defp map_http_version(:SPDY), do: {"SPDY", :"2"}
  defp map_http_version(:QUIC), do: {"QUIC", :"3"}
  defp map_http_version(_other), do: {"", :""}
end
