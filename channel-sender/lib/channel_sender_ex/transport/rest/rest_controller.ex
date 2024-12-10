defmodule ChannelSenderEx.Transport.Rest.RestController do
  @moduledoc """
  Endpoints for internal channel creation and channel message delivery orders
  """
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.PubSub.PubSubCore
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator

  use Plug.Router
  require Logger

  plug(CORSPlug)
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :json],
    json_decoder: {Jason, :decode!, [[keys: :atoms]]}
  )

  plug(:dispatch)

  get("/health", do: send_resp(conn, 200, "UP"))
  post("/ext/channel/create", do: create_channel(conn))
  post("/ext/channel/deliver_message", do: deliver_message(conn))
  match(_, do: send_resp(conn, 404, "Route not found."))

  defp create_channel(conn) do
    route_create(conn.body_params, conn)
  end

  defp route_create(_message = %{
    application_ref: application_ref,
    user_ref: user_ref
   }, conn
  ) do
    {channel_ref, channel_secret} = ChannelAuthenticator.create_channel(application_ref, user_ref)
    response = %{channel_ref: channel_ref, channel_secret: channel_secret}

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, Jason.encode!(response))
  end

  defp route_create(_body, conn) do
    invalid_body(conn)
  end

  defp deliver_message(conn) do
    route_deliver(conn.body_params, conn)
  end

  defp route_deliver(
    message = %{
      channel_ref: channel_ref,
      message_id: _message_id,
      correlation_id: _correlation_id,
      message_data: _message_data,
      event_name: _event_name
     }, conn
   ) do

    Task.start(fn -> PubSubCore.deliver_to_channel(channel_ref,
      Map.drop(message, [:channel_ref]) |> ProtocolMessage.to_protocol_message)
    end)

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(202, Jason.encode!(%{result: "Ok"}))
  end

  defp route_deliver(_, conn), do: invalid_body(conn)

  @compile {:inline, invalid_body: 1}
  defp invalid_body(conn = %{body_params: invalid_body}) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(400, Jason.encode!(%{error: "Invalid request #{inspect(invalid_body)}"}))
  end
end
