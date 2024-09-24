defmodule StreamsApi do
  @moduledoc """
  Documentation for `ChannelStreamsApi`.
  """

  use Application

  alias StreamsApi.Rest.BaseRouter

  @doc false
  @impl Application
  def start(_type, _args) do
    children = [
      {Plug.Cowboy,
      scheme: :http,
      plug: BaseRouter,
      options: [
        port: StreamsHelperConfig.get([:streams, "port"], 8080),
        protocol_options: [max_keepalive: 2_000, active_n: 200]
      ]}
    ]

    opts = [strategy: :one_for_one, name: StreamsApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
