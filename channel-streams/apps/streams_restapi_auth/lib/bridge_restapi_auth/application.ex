defmodule StreamsRestapiAuth.Application do
  @moduledoc false

  use Application
  require Logger

  @doc false
  @impl Application
  def start(_type, _args) do

    children = case (Application.get_env(:streams_core, :env)) do
      e when e in [:test, :bench] ->
        []
      _ ->
        [
          build_child_spec(Application.get_env(:channel_streams, :config))
        ]
    end

    Logger.info("StreamsRestapiAuth.Application starting...")

    opts = [strategy: :one_for_one, name: StreamsRestapiAuth.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def build_child_spec(_config), do: {StreamsRestapiAuth.Oauth.Strategy,
    [first_fetch_sync: true, explicit_alg: "RS256"]}

end
