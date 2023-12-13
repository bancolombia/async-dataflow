defmodule BridgeApi do
  @moduledoc """
  Documentation for `ChannelBridgeApi`.
  """

  use Application

  alias BridgeApi.Rest.BaseRouter

  @doc false
  @impl Application
  def start(_type, _args) do
    children = [
      {Plug.Cowboy,
      scheme: :http,
      plug: BaseRouter,
      options: [
        port: BridgeHelperConfig.get([:bridge, "port"], 8080),
        protocol_options: [max_keepalive: 2_000, active_n: 200]
      ]}
    ]

    opts = [strategy: :one_for_one, name: BridgeApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
