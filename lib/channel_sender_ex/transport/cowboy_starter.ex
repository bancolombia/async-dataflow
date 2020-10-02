defmodule ChannelSenderEx.Transport.CowboyStarter do
  @moduledoc false

  def start_listeners(routes_config) do
    routes_config
    |> Enum.map(fn {name, port, paths} ->
      protocol_opts = %{env: %{dispatch: compile_routes(paths)}}
      :cowboy.start_clear(name, tcp_opts(port), protocol_opts)
    end)
  end

  defp compile_routes(paths) do
    routes = [{_host = :_, paths}]
    :cowboy_router.compile(routes)
  end

  defp tcp_opts(port) do
    [
      port: port,
      backlog: 1024
    ]
  end
end
