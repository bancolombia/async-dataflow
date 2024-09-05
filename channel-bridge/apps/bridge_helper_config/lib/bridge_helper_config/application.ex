defmodule BridgeHelperConfig.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger
  @default_file "config-local.yaml"

  @impl true
  def start(_type, args) do

    config_file_path = case Application.get_env(:bridge_core, :config_file) do
      nil ->
        Logger.warning("No configuration file specified, looking for default file: #{@default_file}")
        @default_file
      value -> value
    end

    new_args = args ++ [file_path: config_file_path]

    children = [
      # Starts a worker by calling: BridgeHelperConfig.Worker.start_link(arg)
      {BridgeHelperConfig.ConfigManager, new_args}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BridgeHelperConfig.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
