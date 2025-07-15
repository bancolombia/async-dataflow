defmodule ChannelSenderEx.Transport.CowboyStarter do
  @moduledoc false

  require Logger
  alias ChannelSenderEx.Transport.CowboyStarter, as: CS
  alias ChannelSenderEx.Utils.CustomTelemetry

  def start_listeners(routes_config) do
    routes_config
    |> Enum.map(fn {name, port, paths} ->
      protocol_opts = %{
        env: %{dispatch: compile_routes(paths)},
        stream_handlers: [:cowboy_metrics_h, :cowboy_stream_h],
        metrics_callback: &CS.metrics_callback/1
      }

      :cowboy.start_clear(name, tcp_opts(port), protocol_opts)
    end)
  end

  def metrics_callback(req) do
    # ! solve this metric collection configuration
    # duration = req.req_end - req.req_start
    # CustomTelemetry.execute_custom_event([:adf, :socket_duration_milliseconds],
    #   %{duration: duration},
    #   %{request_path: "/ext/socket"})

    case req.reason do
      :normal ->
        CustomTelemetry.execute_custom_event(
          [:adf, :socket, :badrequest],
          %{count: 1},
          %{
            request_path: "/ext/socket",
            status: req.resp_status,
            code: get_error_code_header(req)
          }
        )

      :switch_protocol ->
        CustomTelemetry.execute_custom_event(
          [:adf, :socket, :switchprotocol],
          %{count: 1},
          %{request_path: "/ext/socket", status: 101, code: "0"}
        )

      _ ->
        :ok
    end
  rescue
    e -> Logger.warning("Error in metrics callback: #{inspect(e)}")
  end

  defp compile_routes(paths) do
    routes = [{_host = :_, paths}]
    :cowboy_router.compile(routes)
  end

  defp tcp_opts(port) do
    [
      port: port,
      backlog: 4096
    ]
  end

  defp get_error_code_header(req) do
    # extratct an specific key in a map
    case Map.get(req.resp_headers, "x-error-code") do
      nil -> ""
      xcode -> xcode
    end
  end
end
