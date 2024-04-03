defmodule BridgeApi.Rest.RestRouter do
  @moduledoc """
  Endpoints for channel management (creation, update)
  """
  alias BridgeApi.Rest.AuthPlug
  alias BridgeApi.Rest.RestHelper
  alias BridgeApi.Rest.PrometheusExporter
  alias BridgeApi.Rest.Header
  alias BridgeApi.Rest.ChannelRequest
  alias BridgeApi.Rest.Health.Probe, as: HealthProbe

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
  post("/ext/channel", do: start_session(conn))

  # Chanel de-registration end point
  delete("/ext/channel", do: delete_channel(conn))

  get "/liveness" do
    call_probe(conn, &HealthProbe.liveness/0)
  end

  get "/readiness" do
    call_probe(conn, &HealthProbe.readiness/0)
  end

  match(_, do: send_resp(conn, 404, "Resource not found"))

  defp start_session(conn) do
    build_request_data(conn)
    |> RestHelper.start_session()
    |> send_response(conn)
  end

  defp delete_channel(conn) do
    build_request_data(conn)
    |> RestHelper.close_channel()
    |> send_response(conn)
  end

  # @compile {:inline, send_response: 2}
  defp send_response({data, status} = _response, conn) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(status, Jason.encode!(data))
  end

  @spec build_request_data(conn()) :: ChannelRequest.t()
  defp build_request_data(conn) do
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
