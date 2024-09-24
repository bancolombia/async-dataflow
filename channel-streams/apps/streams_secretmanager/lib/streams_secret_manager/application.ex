defmodule StreamsSecretManager.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger
  alias StreamsSecretManager.AwsConfig

  @impl true
  def start(_type, args) do
    children = [
      {StreamsSecretManager, args}
    ]

    AwsConfig.setup_aws_config(
      Application.get_env(:channel_streams, :config)
    )

    Logger.info("StreamsSecretManager.Application starting...")

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: StreamsSecretManager.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
