defmodule BridgeRestapiAuth.Application do
  @moduledoc false

  use Application
  require Logger

  @doc false
  @impl Application
  def start(_type, _args) do

    children = case (Application.get_env(:bridge_core, :env)) do
      e when e in [:test, :bench] ->
        []
      _ ->
        [
          build_child_spec(Application.get_env(:channel_bridge, :config))
        ]
    end

    Logger.info("BridgeRestapiAuth.Application starting...")

    opts = [strategy: :one_for_one, name: BridgeRestapiAuth.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def build_child_spec(_config), do: {BridgeRestapiAuth.Oauth.Strategy,
    [first_fetch_sync: true, explicit_alg: "RS256"]}

end
