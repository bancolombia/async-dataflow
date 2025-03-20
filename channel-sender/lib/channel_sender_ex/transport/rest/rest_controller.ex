defmodule ChannelSenderEx.Transport.Rest.RestController do
  @moduledoc """
  Endpoints for internal channel creation and channel message delivery orders
  """

  alias ChannelSenderEx.Core.HeadlessChannelOperations
  alias ChannelSenderEx.Core.ChannelWorker
  alias Plug.Conn.Query

  use Plug.Router
  use Plug.ErrorHandler

  require Logger

  plug(Plug.Telemetry, event_prefix: [:channel_sender_ex, :plug])
  plug(CORSPlug)
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :json],
    json_decoder: {ChannelSenderEx.Transport.Encoders.JsonEncoder, :decode, [[keys: :strings]]},
    # json_decoder: Jason,
    pass: ["*/*"]
  )

  plug(:dispatch)

  forward(
    "/health",
    to: PlugCheckup,
    init_opts:
      PlugCheckup.Options.new(
        json_encoder: Jason,
        checks: ChannelSenderEx.Transport.Rest.HealthCheck.checks()
      )
  )
  post("/ext/channel/create", do: create_channel(conn))
  post("/ext/channel/gateway/connect", do: connect_client(conn))
  post("/ext/channel/gateway/disconnect", do: disconnect_client(conn))
  post("/ext/channel/gateway/message", do: message_client(conn))
  post("/ext/channel/deliver_message", do: deliver_message(conn))
  delete("/ext/channel", do: close_channel(conn))
  match(_, do: send_resp(conn, 404, "Route not found."))

  defp create_channel(conn) do
    with {:ok, channel_ref, channel_secret} <-
           HeadlessChannelOperations.create_channel(conn.body_params),
         {:ok, response} <-
           Jason.encode(%{channel_ref: channel_ref, channel_secret: channel_secret}) do

      Logger.debug("Rest Controller: Channel created with ref: #{channel_ref}")

      conn
      |> put_resp_header("content-type", "application/json")
      |> send_resp(200, response)
    else
      {:error, _message} -> invalid_body(conn)
    end
  end

  ## ----------------- Gateway endpoints ----------------- ##

  defp connect_client(conn) do
    channel_ref = get_header(conn, "channel")
    connection_id = get_header(conn, "connectionid")

    Logger.debug("Rest Controller: Connection signal to ref: #{channel_ref} and connection[#{connection_id}]")

    {_, result} = HeadlessChannelOperations.on_connect(channel_ref, connection_id)

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, Jason.encode!(%{"message" => result}))
  rescue
    e ->
      Logger.error("Rest Controller: Error accepting channel connection: #{inspect(e)}")

      conn
      |> put_resp_header("content-type", "application/json")
      |> send_resp(200, Jason.encode!(%{"message" => "invalid request"}))
  end

  defp message_client(conn) do
    connection_id = get_header(conn, "connectionid")
    case HeadlessChannelOperations.on_message(conn.body_params, connection_id) do
      {:ok, message} ->
        conn
        |> put_resp_header("content-type", "text/plain")
        |> send_resp(200, message)

      {:unauthorized, message} ->
        conn
        |> put_resp_header("content-type", "text/plain")
        |> send_resp(401, message)
    end
  rescue
    e ->
      Logger.error("Rest Controller: Error processing message: #{inspect(e)}")

      conn
      |> put_resp_header("content-type", "text/plain")
      |> send_resp(200, "[\"\",\"Error\", \"\", \"\"]")
  end

  defp disconnect_client(conn) do
    connection_id = get_header(conn, "connectionid")
    Logger.debug("Rest Controller: Disconnection signal to connection[#{connection_id}]")

    HeadlessChannelOperations.on_disconnect(connection_id)
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, Jason.encode!(%{"message" => "Disconnect acknowledged"}))
  end

  ## ----------------- End Gateweay endpoints ----------------- ##

  defp close_channel(conn) do
    channel =
      conn.query_string
      |> Query.decode()
      |> Map.get("channel_ref", nil)

    case channel do
      nil ->
        invalid_body(conn)

      _ ->
        route_close(channel, conn)
    end
  end

  defp route_close(channel, conn) do
    HeadlessChannelOperations.delete_channel(channel)

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(202, Jason.encode!(%{result: "Ok"}))
  end

  defp deliver_message(conn) do
    route_deliver(conn.body_params, conn)
  end

  defp route_deliver(
         message = %{
           "channel_ref" => _channel_ref,
           "message_id" => _message_id,
           "correlation_id" => _correlation_id,
           "message_data" => _message_data,
           "event_name" => _event_name
         },
         conn
       ) do
    assert_deliver_request(message)
    |> perform_delivery()
    |> build_and_send_response(conn)
  end

  defp route_deliver(_body, conn) do
    invalid_body(conn)
  end

  # """
  # Asserts that the message is a valid delivery request
  # """
  @spec assert_deliver_request(map()) :: {:ok, map()} | {:error, :invalid_message}
  defp assert_deliver_request(message) do
    # Check if minimal fields are present and not nil
    result =
      Enum.all?(message, fn {key, value} ->
        case key do
          "message_data" ->
            not is_nil(value)

          "correlation_id" ->
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

  defp perform_delivery({:ok, message}) do
    ChannelWorker.route_message(message)
    {202, %{result: "Ok"}}
  end

  defp perform_delivery(e = {:error, :invalid_message}) do
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
    response =
      case conn.status do
        400 ->
          Jason.encode!(%{error: "Invalid or malformed request body"})

        500 ->
          Jason.encode!(%{error: "Internal server error"})

        _ ->
          Jason.encode!(%{error: "Unknown error"})
      end

    Logger.error("Rest Controller: Error detected in request: #{inspect(reason)}, response will be: #{response}")

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(conn.status, response)
  end

  defp get_header(conn, name) do
    conn.req_headers
    |> Enum.filter(fn {key, _} -> key == name end)
    |> Enum.map(fn {_, value} -> value end)
    |> List.first()
  end


end
