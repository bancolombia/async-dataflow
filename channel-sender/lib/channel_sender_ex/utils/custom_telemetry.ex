defmodule ChannelSenderEx.Utils.CustomTelemetry do
  @moduledoc false

  import Telemetry.Metrics
  alias ChannelSenderEx.Utils.CustomTelemetry, as: CT
  @service_name "channel_sender_ex"

  def custom_telemetry_events do
    :telemetry.attach("channel_sender_ex-plug-stop", [:channel_sender_ex, :plug, :stop],
      &CT.handle_custom_event/4, nil)
    :telemetry.attach(
        "cowboy-telemetry-logger",
        [:cowboy, :request, :stop],
        &CT.handle_custom_event/4,
        nil
      )
    :telemetry.attach("vm-memory", [:vm, :memory],
      &CT.handle_custom_event/4, nil)
    :telemetry.attach("vm-total_run_queue_lengths", [:vm, :total_run_queue_lengths],
      &CT.handle_custom_event/4, nil)
    :telemetry.attach("adf-message-delivered", [:adf, :message, :delivered],
      &CT.handle_custom_event/4, nil)
    :telemetry.attach("adf-message-nodelivered", [:adf, :message, :nodelivered],
      &CT.handle_custom_event/4, nil)
    :telemetry.attach("adf-socket-failure", [:adf, :socket, :failure],
      &CT.handle_custom_event/4, nil)
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
      %{request_path: metadata.conn.request_path, status: metadata.conn.status, service: @service_name}
    )
  end

  def handle_custom_event(metric, measures, metadata, _) do
    metadata = Map.put(metadata, :service, @service_name)
    :telemetry.execute([:elixir | metric], measures, metadata)
  end

  def metrics do
    [
      # Plug Metrics
      counter("elixir.http_request_duration_milliseconds.count", tags: [:request_path, :status, :service]),
      sum("elixir.http_request_duration_milliseconds.duration", tags: [:request_path, :status, :service]),

      #Custom Metrics
      counter("elixir.adf.message.requested.count", tags: [:service]),
      counter("elixir.adf.message.delivered.count", tags: [:service]),
      counter("elixir.adf.message.nodelivered.count", tags: [:service]),

      counter("elixir.adf.socket.badrequest.count", tags: [:request_path, :status, :code, :service]),
      counter("elixir.adf.socket.switchprotocol.count", tags: [:request_path, :status, :code, :service]),
      counter("elixir.adf.socket.connection.count", tags: [:service]),
      counter("elixir.adf.socket.disconnection.count", tags: [:service]),
      counter("elixir.adf.socket_duration_milliseconds.count", tags: [:request_path, :service]),
      counter("elixir.adf.channel.created.count", tags: [:service]),
      counter("elixir.adf.channel.deleted.count", tags: [:service]),

      counter("elixir.adf.sse.connection.count", tags: [:service]),
      counter("elixir.adf.sse.badrequest.count", tags: [:status, :code, :service]),

      sum("elixir.adf.channel.waiting.count", tags: [:service], reporter_options: [report_as: :counter]),
      sum("elixir.adf.channel.connected.count", tags: [:service], reporter_options: [report_as: :counter]),
      sum("elixir.adf.channel.created_on_socket.count", tags: [:service], reporter_options: [report_as: :counter]),
      sum("elixir.adf.channel.pending.send.count", tags: [:service], reporter_options: [report_as: :counter]),
      sum("elixir.adf.channel.pending.ack.count", tags: [:service], reporter_options: [report_as: :counter]),

      # VM Metrics
      last_value("elixir.vm.memory.total", unit: {:byte, :kilobyte}, tags: [:service]),
      last_value("elixir.vm.memory.processes", unit: {:byte, :kilobyte}, tags: [:service]),
      last_value("elixir.vm.memory.binary", unit: {:byte, :kilobyte}, tags: [:service]),
      last_value("elixir.vm.memory.ets", unit: {:byte, :kilobyte}, tags: [:service]),
      last_value("elixir.vm.total_run_queue_lengths.total", tags: [:service]),
      last_value("elixir.vm.total_run_queue_lengths.cpu", tags: [:service]),
      last_value("elixir.vm.total_run_queue_lengths.io", tags: [:service]),
      last_value("elixir.vm.system_counts_process.count", tags: [:service])
    ]
  end

  def monotonic_time_to_milliseconds(monotonic_time) do
    monotonic_time |> System.convert_time_unit(:native, :millisecond)
  end
end
