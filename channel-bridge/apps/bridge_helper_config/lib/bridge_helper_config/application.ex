defmodule BridgeHelperConfig.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, args) do
    children = [
      # Starts a worker by calling: BridgeHelperConfig.Worker.start_link(arg)
      {BridgeHelperConfig.ConfigManager, args}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BridgeHelperConfig.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
