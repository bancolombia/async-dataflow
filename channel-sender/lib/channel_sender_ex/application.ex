defmodule ChannelSenderEx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  alias ChannelSenderEx.ApplicationConfig
  alias ChannelSenderEx.Core.RulesProvider.Helper
  alias ChannelSenderEx.Persistence.ChannelPersistence
  alias ChannelSenderEx.Transport.EntryPoint
  alias ChannelSenderEx.Transport.Rest.RestController
  alias ChannelSenderEx.Utils.ClusterUtils
  alias ChannelSenderEx.Utils.CustomTelemetry

  use Application
  require Logger
  @default_prometheus_port 9568

  def start(_type, _args) do

    _config = ApplicationConfig.load()

    ClusterUtils.discover_and_connect_local()
    Helper.compile(:channel_sender_ex)
    CustomTelemetry.custom_telemetry_events()

    no_start_param = Application.get_env(:channel_sender_ex, :no_start)
    if !no_start_param do
      EntryPoint.start()
    end

    opts = [strategy: :one_for_one, name: ChannelSenderEx.Supervisor]
    Supervisor.start_link(children(no_start_param), opts)
  end

  defp children(_no_start_param = true), do: []

  defp children(_no_start_param = false) do
    prometheus_port = Application.get_env(:channel_sender_ex, :prometheus_ports, @default_prometheus_port)

    [
      {Cluster.Supervisor, [topologies(), [name: ChannelSenderEx.ClusterSupervisor]]},
      ChannelSenderEx.Core.ChannelRegistry,
      ChannelSenderEx.Core.ChannelSupervisor,
      ChannelSenderEx.Core.NodeObserver,
      {Plug.Cowboy,
       scheme: :http,
       plug: RestController,
       options: [
         port: Application.get_env(:channel_sender_ex, :rest_port)
       ]},
      {TelemetryMetricsPrometheus,
       [
         metrics: CustomTelemetry.metrics(),
         port: prometheus_port
       ]},
      # {Telemetry.Metrics.ConsoleReporter, metrics: CustomTelemetry.metrics()},
      {Finch, name: AwsConnectionsFinch},
      :poolboy.child_spec(:worker, poolboy_config())
    ] ++ ChannelPersistence.child_spec()
  end

  defp topologies do
    topology = [
      k8s: Application.get_env(:channel_sender_ex, :topology)
    ]
    Logger.debug("Topology selected: #{inspect(topology)}")
    topology
  end

  defp poolboy_config do
    [
      name: {:local, :worker},
      worker_module: ChannelSenderEx.Core.ChannelWorker,
      size: 80,
      max_overflow: 20
    ]
  end
end
