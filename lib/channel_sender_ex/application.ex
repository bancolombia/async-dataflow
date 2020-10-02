defmodule ChannelSenderEx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  alias ChannelSenderEx.Transport.Rest.RestController
  alias ChannelSenderEx.Transport.EntryPoint

  use Application

  def start(_type, _args) do
    ChannelSenderEx.Utils.ClusterUtils.discover_and_connect_local()
    http_port = Application.get_env(:channel_sender_ex, :rest_port, 8080)

    children = [
      {Horde.Registry, [name: ChannelSenderEx.DistributedRegistry, keys: :unique]},
      {Horde.DynamicSupervisor,
       [name: ChannelSenderEx.DistributedSupervisor, strategy: :one_for_one]},
      {Plug.Cowboy, scheme: :http, plug: RestController, options: [port: http_port]}
    ]

    EntryPoint.start()

    opts = [strategy: :one_for_one, name: ChannelSenderEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
