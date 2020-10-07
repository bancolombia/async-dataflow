defmodule ChannelSenderEx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  alias ChannelSenderEx.Transport.Rest.RestController
  alias ChannelSenderEx.Transport.EntryPoint
  alias ChannelSenderEx.Core.ChannelSupervisor
  alias ChannelSenderEx.Core.ChannelRegistry

  use Application

  @supervisor_module Application.get_env(:channel_sender_ex, :channel_supervisor_module)
  @registry_module Application.get_env(:channel_sender_ex, :registry_module)
  @no_start Application.get_env(:channel_sender_ex, :no_start)
  @http_port Application.get_env(:channel_sender_ex, :rest_port, 8080)

  def start(_type, _args) do
    ChannelSenderEx.Utils.ClusterUtils.discover_and_connect_local()

    if !@no_start do
      EntryPoint.start()
    end

    opts = [strategy: :one_for_one, name: ChannelSenderEx.Supervisor]
    Supervisor.start_link(children(@no_start), opts)
  end

  defp children(_no_start = false) do
    [
      {@registry_module, name: ChannelRegistry, keys: :unique},
      {@supervisor_module, name: ChannelSupervisor, strategy: :one_for_one},
      {Plug.Cowboy, scheme: :http, plug: RestController, options: [port: @http_port]}
    ]
  end

  defp children(_no_start = true), do: []

end
