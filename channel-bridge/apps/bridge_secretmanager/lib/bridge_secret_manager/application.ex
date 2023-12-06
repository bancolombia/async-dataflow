defmodule BridgeSecretManager.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger
  alias BridgeSecretManager.AwsConfig

  @impl true
  def start(_type, args) do
    children = [
      {BridgeSecretManager, args}
    ]

    AwsConfig.setup_aws_config(
      Application.get_env(:channel_bridge, :config)
    )

    Logger.info("BridgeSecretManager.Application starting...")

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BridgeSecretManager.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
