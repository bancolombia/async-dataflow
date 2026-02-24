defmodule ChannelSenderEx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  alias ChannelSenderEx.ApplicationConfig
  alias ChannelSenderEx.Core.RulesProvider.Helper
  alias ChannelSenderEx.Transport.EntryPoint
  alias ChannelSenderEx.Transport.Rest.RestController
  alias ChannelSenderEx.Utils.CustomTelemetry

  @default_prometheus_port 9568

  use Application
  require Logger

  def start(_type, _args) do
    _config = ApplicationConfig.load()

    open_telemetry_traces()
    open_telemetry_metrics()

    Helper.compile(:channel_sender_ex)

    no_start_param = Application.get_env(:channel_sender_ex, :no_start)

    if !no_start_param do
      EntryPoint.start()
    end

    opts = [strategy: :one_for_one, name: ChannelSenderEx.Supervisor]
    Supervisor.start_link(children(no_start_param), opts)
  end

  defp children(no_start_param) do
    case no_start_param do
      false ->
        [
          {Cluster.Supervisor, [topologies(), [name: ChannelSenderEx.ClusterSupervisor]]},
          pg_spec(),
          ChannelSenderEx.Core.ChannelSupervisor,
          {Plug.Cowboy,
           scheme: :http,
           plug: RestController,
           options: [
             port: Application.get_env(:channel_sender_ex, :rest_port),
             protocol_options: Application.get_env(:channel_sender_ex, :cowboy_protocol_options),
             transport_options: Application.get_env(:channel_sender_ex, :cowboy_transport_options)
           ]}
        ] ++ metrics_children()

      true ->
        []
    end
  end

  defp topologies do
    topology = [
      k8s: Application.get_env(:channel_sender_ex, :topology)
    ]

    Logger.debug("Topology selected: #{inspect(topology)}")
    topology
  end

  defp pg_spec do
    %{
      id: :pg,
      start: {:pg, :start_link, []}
    }
  end

  defp open_telemetry_traces do
    traces_enabled? = Application.get_env(:channel_sender_ex, :traces_enable, false)

    if traces_enabled? do
      traces_endpoint = Application.get_env(:channel_sender_ex, :traces_endpoint)
      traces_ignore_routes = Application.get_env(:channel_sender_ex, :traces_ignore_routes)

      Application.put_env(:opentelemetry, :text_map_propagators, [:baggage, :trace_context])
      Application.put_env(:opentelemetry, :span_processor, :batch)
      Application.put_env(:opentelemetry, :traces_exporter, :otlp)

      Application.put_env(:opentelemetry, :resource_detectors, [
        :otel_resource_app_env,
        :otel_resource_env_var,
        OtelResourceDynatrace
      ])

      Application.put_env(:opentelemetry_exporter, :otlp_endpoint, traces_endpoint)

      Application.put_env(:opentelemetry_plug, :ignored_routes, traces_ignore_routes)

      Application.ensure_all_started(:gproc)
      Application.ensure_all_started(:telemetry)
      Application.ensure_all_started(:opentelemetry_exporter)
      Application.ensure_all_started(:opentelemetry)

      Logger.warning("Tracing is enabled, setting up OpentelemetryPlug.")
      OpentelemetryPlug.setup()
    end
  end

  defp open_telemetry_metrics do
    metrics_enabled? = Application.get_env(:channel_sender_ex, :metrics_enabled, false)

    if metrics_enabled? do
      Logger.warning("Metrics are enabled, setting up CustomTelemetry.")
      CustomTelemetry.custom_telemetry_events()
    end
  end

  defp metrics_children do
    metrics_enabled? = Application.get_env(:channel_sender_ex, :metrics_enabled, false)

    if metrics_enabled? do
      prometheus_port =
        Application.get_env(:channel_sender_ex, :prometheus_port, @default_prometheus_port)

      [
        {TelemetryMetricsPrometheus, [metrics: CustomTelemetry.metrics(), port: prometheus_port]},
        ChannelSenderEx.Utils.ChannelMetrics
        # {Telemetry.Metrics.ConsoleReporter, metrics: CustomTelemetry.metrics()}
      ]
    else
      []
    end
  end
end
