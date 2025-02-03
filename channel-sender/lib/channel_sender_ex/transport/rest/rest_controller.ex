defmodule ChannelSenderEx.Transport.Rest.RestController do
  @moduledoc """
  Endpoints for internal channel creation and channel message delivery orders
  """
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.PubSub.PubSubCore
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator

  use Plug.Router
  use Plug.ErrorHandler

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

    assert_deliver_request(message)
    |> perform_delivery(%{"channel_ref" => channel_ref})
    |> build_and_send_response(conn)

  end

  defp route_deliver(_, conn), do: invalid_body(conn)

  #"""
  # Asserts that the message is a valid delivery request
  #"""
  @spec assert_deliver_request(map()) :: {:ok, map()} | {:error, :invalid_message}
  defp assert_deliver_request(message) do
    # Check if minimal fields are present and not nil
    result = message
    |> Enum.all?(fn {key, value} ->
      case key do
        :message_data ->
          not is_nil(value)
        :correlation_id ->
          true
        _ ->
          is_binary(value) and value != ""
      end
    end)

    case result do
      true ->
        {:ok, message}
      false ->
        {:error, :invalid_message}
    end
  end

  defp perform_delivery({:ok, message}, %{"channel_ref" => channel_ref}) do
    Task.start(fn ->
      new_msg = message
      |> Map.drop([:channel_ref])
      |> ProtocolMessage.to_protocol_message

      PubSubCore.deliver_to_channel(channel_ref, new_msg)
    end)
    {202, %{result: "Ok"}}
  end

  defp perform_delivery(e = {:error, :invalid_message}, _) do
    {400, e}
  end

  defp build_and_send_response({202, body}, conn) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(202, Jason.encode!(body))
  end

  defp build_and_send_response({400, _}, conn) do
    invalid_body(conn)
  end

  @compile {:inline, invalid_body: 1}
  defp invalid_body(conn = %{body_params: invalid_body}) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(400, Jason.encode!(%{error: "Invalid request", request: invalid_body}))
  end

  @impl Plug.ErrorHandler
  def handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack}) do
    response = case conn.status do
      400 ->
        Jason.encode!(%{error: "Invalid or malformed request body"})
      500 ->
        Jason.encode!(%{error: "Internal server error"})
      _ ->
        Jason.encode!(%{error: "Unknown error"})
    end
    Logger.error("Error detected in request: #{inspect(reason)}, response will be: #{response}")
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(conn.status, response)
  end

end
