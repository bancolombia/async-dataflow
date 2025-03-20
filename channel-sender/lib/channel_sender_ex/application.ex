defmodule ChannelSenderEx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  alias ChannelSenderEx.ApplicationConfig
  alias ChannelSenderEx.Core.RulesProvider.Helper
  alias ChannelSenderEx.Transport.EntryPoint
  alias ChannelSenderEx.Transport.Rest.RestController
  alias ChannelSenderEx.Utils.CustomTelemetry

  use Application
  require Logger

  def start(_type, _args) do

    _config = ApplicationConfig.load()

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
    case no_start_param do
      false ->
        [
          {Cluster.Supervisor, [topologies(), [name: ChannelSenderEx.ClusterSupervisor]]},
          ChannelSenderEx.Core.ChannelSupervisor,
          {Plug.Cowboy, scheme: :http, plug: RestController, options: [
            port: Application.get_env(:channel_sender_ex, :rest_port),
          ]},
          {TelemetryMetricsPrometheus, [metrics: CustomTelemetry.metrics()]},
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
end
