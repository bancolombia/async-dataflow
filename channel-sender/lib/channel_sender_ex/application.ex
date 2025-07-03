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
    config = ApplicationConfig.load()

    open_telemetry_traces(config)

    Helper.compile(:channel_sender_ex)
    CustomTelemetry.custom_telemetry_events()

    no_start_param = Application.get_env(:channel_sender_ex, :no_start)

    if !no_start_param do
      EntryPoint.start()
    end

    opts = [strategy: :one_for_one, name: ChannelSenderEx.Supervisor]
    Supervisor.start_link(children(no_start_param), opts)
  end

  defp children(no_start_param) do
    prometheus_port =
      Application.get_env(:channel_sender_ex, :prometheus_port, @default_prometheus_port)

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
           ]},
          {TelemetryMetricsPrometheus,
           [
             metrics: CustomTelemetry.metrics(),
             port: prometheus_port
           ]}
          # {Telemetry.Metrics.ConsoleReporter, metrics: CustomTelemetry.metrics()}
        ]

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

  defp open_telemetry_traces(config) do
    traces_enable = get_in(config, [:channel_sender_ex, "opentelemetry", "traces_enable"])

    if traces_enable do
      traces_endpoint = get_in(config, [:channel_sender_ex, "opentelemetry", "traces_endpoint"])

      traces_ignore_routes =
        get_in(config, [:channel_sender_ex, "opentelemetry", "traces_ignore_routes"])

      Application.put_env(:opentelemetry, :text_map_propagators, [:baggage, :trace_context])
      Application.put_env(:opentelemetry, :span_processor, :batch)
      Application.put_env(:opentelemetry, :traces_exporter, :otlp)

      Application.put_env(:opentelemetry, :resource_detectors, [
        :otel_resource_app_env,
        :otel_resource_env_var,
        OtelResourceDynatrace
      ])

      Application.put_env(:opentelemetry_exporter, :otlp_protocol, :http_protobuf)
      Application.put_env(:opentelemetry_exporter, :otlp_endpoint, traces_endpoint)

      Application.put_env(:opentelemetry_plug, :ignored_routes, traces_ignore_routes)

      Logger.warning("Tracing is enabled, setting up OpentelemetryPlug.")
      OpentelemetryPlug.setup()
    end
  end
end
