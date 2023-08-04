defmodule ChannelSenderEx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  alias ChannelSenderEx.Transport.Rest.RestController
  alias ChannelSenderEx.Transport.EntryPoint
  alias ChannelSenderEx.ApplicationConfig

  use Application
  require Logger

  def start(_type, _args) do

    _config = ApplicationConfig.load()

    ChannelSenderEx.Utils.ClusterUtils.discover_and_connect_local()
    ChannelSenderEx.Core.RulesProvider.Helper.compile(:channel_sender_ex)

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
          ChannelSenderEx.Core.ChannelRegistry,
          ChannelSenderEx.Core.ChannelSupervisor,
          ChannelSenderEx.Core.NodeObserver,
          {Plug.Cowboy, scheme: :http, plug: RestController, options: [
            port: Application.get_env(:channel_sender_ex, :rest_port)
          ]}
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
