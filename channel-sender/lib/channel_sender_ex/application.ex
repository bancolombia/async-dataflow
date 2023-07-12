defmodule ChannelSenderEx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  alias ChannelSenderEx.Transport.Rest.RestController
  alias ChannelSenderEx.Transport.EntryPoint
  use Application
  @no_start Application.get_env(:channel_sender_ex, :no_start)
  @http_port Application.get_env(:channel_sender_ex, :rest_port, 8080)
  @topology Application.get_env(:channel_sender_ex, :topology, [ strategy: Cluster.Strategy.Gossip ])

  def start(_type, _args) do
    ChannelSenderEx.Utils.ClusterUtils.discover_and_connect_local()
    ChannelSenderEx.Core.RulesProvider.Helper.compile(:channel_sender_ex)

    if !@no_start do
      EntryPoint.start()
    end

    opts = [strategy: :one_for_one, name: ChannelSenderEx.Supervisor]
    Supervisor.start_link(children(@no_start), opts)
  end

  defp children(_no_start = false) do
    [
      {Cluster.Supervisor, [topologies(), [name: ChannelSenderEx.ClusterSupervisor]]},
      ChannelSenderEx.Core.ChannelRegistry,
      ChannelSenderEx.Core.ChannelSupervisor,
      ChannelSenderEx.Core.NodeObserver,
      {Plug.Cowboy, scheme: :http, plug: RestController, options: [port: @http_port]}
    ]
  end

  defp children(_no_start = true), do: []

  defp topologies do
    [
      background_job: @topology
    ]
  end
end
