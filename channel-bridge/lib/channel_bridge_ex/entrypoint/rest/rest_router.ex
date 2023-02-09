defmodule ChannelBridgeEx.Entrypoint.Rest.RestRouter do
  @moduledoc """
  Endpoints for channel management (creation, update)
  """
  alias ChannelBridgeEx.Entrypoint.Rest.AuthPlug
  alias ChannelBridgeEx.Entrypoint.Rest.RestHelper
  alias ChannelBridgeEx.Entrypoint.Rest.PrometheusExporter
  alias ChannelBridgeEx.Entrypoint.Rest.Header
  alias ChannelBridgeEx.Core.Channel.ChannelRequest
  alias ChannelBridgeEx.Entrypoint.Rest.Health.Probe, as: HealthProbe

  use Plug.Router
  use Plug.ErrorHandler
  require Logger

  @type conn :: %Plug.Conn{}

  plug(Plug.Telemetry, event_prefix: [:web, :plug])
  plug(PrometheusExporter)
  plug(AuthPlug)
  plug(CORSPlug)
  plug(:match)
  plug(:dispatch)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :json],
    json_decoder: {Jason, :decode!, [[keys: :atoms]]}
  )

  # Chanel registration endpoint
  post("/ext/channel", do: register_channel(conn))

  # Chanel de-registration end point
  delete("/ext/channel", do: delete_channel(conn))

  get "/liveness" do
    call_probe(conn, &HealthProbe.liveness/0)
  end

  get "/readiness" do
    call_probe(conn, &HealthProbe.readiness/0)
  end

  match(_, do: send_resp(conn, 404, "Resource not found"))

  defp register_channel(conn) do
    build_data_map(conn)
    |> RestHelper.start_channel()
    |> send_response(conn)
  end

  defp delete_channel(conn) do
    build_data_map(conn)
    |> RestHelper.close_channel()
    |> send_response(conn)
  end

  # @compile {:inline, send_response: 2}
  defp send_response({data, status} = _response, conn) do
    conn
    |> put_resp_header("Content-Type", "application/json")
    |> send_resp(status, Jason.encode!(data))
  end

  @spec build_data_map(conn()) :: ChannelRequest.t()
  defp build_data_map(conn) do
    {:ok, all_headers} = Header.all_headers(conn)

    ChannelRequest.new(
      all_headers,
      conn.query_params,
      conn.body_params,
      conn.private[:token_claims]
    )
  end

  defp call_probe(conn, fun) do
    case fun.() do
      :ok ->
        send_resp(conn, Plug.Conn.Status.code(:ok), "OK")
      _ ->
        send_resp(conn, 503, "Service Unavailable")
    end
  end

end
