defmodule ChannelSenderEx.Transport.Rest.RestController do
  @moduledoc """
  Endpoints for internal channel creation and channel message delivery orders
  """
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
  alias ChannelSenderEx.Core.PubSub.PubSubCore
  alias ChannelSenderEx.Core.ProtocolMessage

  use Plug.Router
  require Logger

  plug(CORSPlug)
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :json],
    json_decoder: {Jason, :decode!, [[keys: :atoms]]}
  )

  plug(:dispatch)

  post("/ext/channel/create", do: create_channel(conn))
  post("/ext/channel/deliver_message", do: deliver_message(conn))

  defp create_channel(
         conn = %{body_params: %{application_ref: application_ref, user_ref: user_ref}}
       ) do
    :telemetry.execute([:app, :create_channel], %{count: 1}, %{})
    {response, code} =
      case ChannelAuthenticator.create_channel(application_ref, user_ref) do
        {:error, :no_app} ->
          {%{error: "No application #{application_ref} found"}, 412}

        {channel_ref, channel_secret} ->
          {%{channel_ref: channel_ref, channel_secret: channel_secret}, 200}
      end

    conn
    |> put_resp_header("Content-Type", "application/json")
    |> send_resp(code, Jason.encode!(response))
  end

  defp create_channel(conn), do: invalid_body(conn)

  defp deliver_message(
         conn = %{
           body_params:
             message = %{
               channel_ref: channel_ref,
               message_id: _message_id,
               correlation_id: _correlation_id,
               message_data: _message_data,
               event_name: _event_name
             }
         }
       ) do
    :telemetry.execute([:app, :deliver_message], %{count: 1}, %{})
    _result =
      PubSubCore.deliver_to_channel(channel_ref, ProtocolMessage.to_protocol_message(message))

    send_resp(conn, 202, "Ok")
  end

  defp deliver_message(conn), do: invalid_body(conn)

  @compile {:inline, invalid_body: 1}
  defp invalid_body(conn = %{body_params: invalid_body}) do
    conn
    |> put_resp_header("Content-Type", "application/json")
    |> send_resp(400, Jason.encode!(%{error: "Invalid request #{inspect(invalid_body)}"}))
  end
end
