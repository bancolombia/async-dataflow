defmodule ChannelSenderEx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  alias ChannelSenderEx.Transport.Rest.RestController

  use Application

  def start(_type, _args) do
    http_port = Application.get_env(:channel_sender_ex, :rest_port, 8080)

    children = [
      # Starts a worker by calling: ChannelSenderEx.Worker.start_link(arg)
      # {ChannelSenderEx.Worker, arg}
      {Plug.Cowboy, scheme: :http, plug: RestController, options: [port: http_port]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ChannelSenderEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
