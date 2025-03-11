defmodule ChannelSenderEx.Transport.Rest.RestController do
  @moduledoc """
  Endpoints for internal channel creation and channel message delivery orders
  """

  alias ChannelSenderEx.Adapter.WsConnections
  alias ChannelSenderEx.Persistence.ChannelPersistence
  alias ChannelSenderEx.Core.Data
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.PubSub.PubSubCore
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
  alias Plug.Conn.Query

  use Plug.Router
  use Plug.ErrorHandler

  require Logger

  @metadata_headers_max 3
  @metadata_headers_prefix "x-meta-"

  plug(Plug.Telemetry, event_prefix: [:channel_sender_ex, :plug])
  plug(CORSPlug)
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :json],
    json_decoder: {Jason, :decode!, [[keys: :strings]]}
  )

  plug(:dispatch)

  get("/health", do: send_resp(conn, 200, "UP"))
  post("/ext/channel/create", do: create_channel(conn))

  post("/ext/channel/gateway/connect", do: connect_client(conn))
  post("/ext/channel/gateway/disconnect", do: disconnect_client(conn))
  post("/ext/channel/gateway/message", do: message_client(conn))

  post("/ext/channel/deliver_message", do: deliver_message(conn))
  post("/ext/channel/deliver_batch", do: deliver_message(conn))
  delete("/ext/channel", do: close_channel(conn))
  match(_, do: send_resp(conn, 404, "Route not found."))

  defp create_channel(conn) do
    # collect metadata from headers, up to 3 metadata fields
    headers = conn.req_headers
    |> Enum.filter(fn {key, _} -> String.starts_with?(key, @metadata_headers_prefix) end)
    |> Enum.map(fn {key, value} -> {String.replace(key, @metadata_headers_prefix, ""), String.slice(value, 0, 50)} end)
    |> Enum.take(@metadata_headers_max)
    route_create(conn.body_params, %{"headers" => headers, "postponed" => %{}}, conn)
  end

  @spec route_create(map(), map(), Plug.Conn.t()) :: Plug.Conn.t()
  defp route_create(message = %{
    "application_ref" => application_ref,
    "user_ref" => user_ref
  }, metadata, conn
  ) do

    is_valid = message
    |> Enum.all?(fn {_, value} -> is_binary(value) and value != "" end)

    case is_valid do
      true ->
        {channel_ref, channel_secret} = ChannelAuthenticator.create_channel(application_ref, user_ref, metadata)

        # invocar al worker
        Task.start(fn ->
          ChannelPersistence.save_channel_data(Data.new(channel_ref, application_ref, user_ref, metadata))
        end)

        response = %{channel_ref: channel_ref, channel_secret: channel_secret}

        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(200, Jason.encode!(response))

      false ->
        invalid_body(conn)
    end
  end

  defp route_create(_body, _metadata, conn) do
    invalid_body(conn)
  end

  ## ----------------- Gateway endpoints ----------------- ##

  defp connect_client(conn) do
    route_connect(get_header(conn, "channel"),
      get_header(conn, "connectionid"), conn)
  rescue
    e ->
      Logger.error("Error authorizing channel: #{inspect(e)}")
      conn
      |> put_resp_header("content-type", "application/json")
      |> send_resp(200, Jason.encode!(%{"message" => "invalid request"}))
  end

  defp route_connect(channel, connection_id, conn) do
    result = case PubSubCore.channel_exists?(channel) do
      {true, _pid} ->
        Logger.debug("Channel #{channel} validation response: true")
        Task.start(fn ->
          ChannelPersistence.save_socket_data(connection_id, channel)
        end)
        Jason.encode!("{\"result\": \"OK\"}")

      false ->
        Logger.error("Channel #{channel} validation response: Channel does not exist")

        # the channel does not exist, close the connection
        Task.start(fn ->
          Process.sleep(50) # must wait for the socket to be fully created in AWS, for the send data and close to work
          WsConnections.send_data(connection_id, "[\"\",\"Error::3008\", \"\", \"\"]")
          Process.sleep(50)
          WsConnections.close(connection_id)
        end)

        Jason.encode!("{\"result\": \"4001\"}")
    end

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, result)
  end

  defp message_client(conn) do
    process_message(conn.body_params, get_header(conn, "connectionid"), conn)
  rescue
    e ->
      Logger.error("Error processing message: #{inspect(e)}")
      conn
      |> put_resp_header("content-type", "text/plain")
      |> send_resp(200, "[\"\",\"Error\", \"\", \"\"]")
  end

  defp process_message(message = %{
    "action" => _action,
    "channel" => channel,
    "secret" => secret
   }, connection_id, conn) do

    Logger.debug("Authorization message #{inspect(message)}")

    case ChannelAuthenticator.authorize_channel(channel, secret) do
      {:ok, _application, _user_ref} ->
        Logger.debug("Authorized channel Success #{channel}")
        # update the channel process with the socket connection id
        Task.start(fn ->
          PubSubCore.update_connection_id(channel, connection_id)
        end)

        conn
        |> put_resp_header("content-type", "text/plain")
        |> send_resp(200, "[\"\",\"AuthOK\", \"\", \"\"]")

      :unauthorized ->
        Logger.error("Unauthorized channel #{channel}")

        result = conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(401, "[\"\",\"AuthFailed\", \"\", \"\"]")

        Task.start(fn ->
          Process.sleep(50)
          WsConnections.close(connection_id)
        end)
        result
    end
  rescue
    e ->
      Logger.error("Error authorizing channel : #{inspect(e)}")
      conn
      |> put_resp_header("content-type", "text/plain")
      |> send_resp(400, "[\"\",\"AuthError\", \"\", \"\"]")
  end

  defp process_message(message = %{
    "action" => _action,
    "channel" => channel,
    "ack_message_id" => message_id
   }, _connection_id, conn) do

    Logger.debug("Ack message #{inspect(message)}")

    PubSubCore.ack_message(channel, message_id)

    conn
    |> put_resp_header("content-type", "text/plain")
    |> send_resp(200, "[\"\",\"AckOK\", \"\", \"\"]")

  rescue
    e ->
      Logger.error("Error ACK message : #{inspect(e)}")
      conn
      |> put_resp_header("content-type", "text/plain")
      |> send_resp(400, "[\"\",\"AckError\", \"\", \"\"]")
  end

  defp disconnect_client(conn) do
    IO.inspect(conn, label: "OnDisconnect Request")
    case ChannelPersistence.get_channel_data("socket_" <> get_header(conn,"connectionid")) do
      {:ok, loaded_data} ->
        PubSubCore.update_connection_id(loaded_data.channel, "")
        Task.start(fn ->
          ChannelPersistence.delete_channel_data("socket_" <> get_header(conn,"connectionid"))
        end)
      {:error, _} ->
        :ok
    end
    conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(200, Jason.encode!(%{"message" => "Disconnect acknowledged"}))
  end

  ## ----------------- End Gateweay endpoints ----------------- ##

  defp close_channel(conn) do
    channel = conn.query_string
    |> Query.decode
    |> Map.get("channel_ref", nil)
    case channel do
      nil ->
        invalid_body(conn)

      _ ->
        route_close(channel, conn)
    end
  end

  defp route_close(channel, conn) do

    Task.start(fn ->
      PubSubCore.delete_channel(channel)
    end)

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(202, Jason.encode!(%{result: "Ok"}))

  end

  defp deliver_message(conn) do
    route_deliver(conn.body_params, conn)
  end

  defp route_deliver(_body = %{
    "messages" => messages
    }, conn) do

    # takes N first messages and separates them into valid and invalid messages
    {valid_messages, invalid_messages} = batch_separate_messages(messages)

    valid_messages
    |> perform_delivery

    batch_build_response({valid_messages, invalid_messages}, messages, conn)
  end

  defp route_deliver(
    message = %{
      "channel_ref" => channel_ref,
      "message_id" => _message_id,
      "correlation_id" => _correlation_id,
      "message_data" => _message_data,
      "event_name" => _event_name
     }, conn
   ) do
    assert_deliver_request(message)
    |> perform_delivery(%{"channel_ref" => channel_ref})
    |> build_and_send_response(conn)
  end

  defp route_deliver(
        message = %{
          "app_ref" => app_ref,
          "message_id" => _message_id,
          "correlation_id" => _correlation_id,
          "message_data" => _message_data,
          "event_name" => _event_name
        }, conn
      ) do

    assert_deliver_request(message)
    |> perform_delivery(%{"app_ref" => app_ref})
    |> build_and_send_response(conn)

  end

  defp route_deliver(
    message = %{
      "user_ref" => user_ref,
      "message_id" => _message_id,
      "correlation_id" => _correlation_id,
      "message_data" => _message_data,
      "event_name" => _event_name
    }, conn
  ) do

    assert_deliver_request(message)
    |> perform_delivery(%{"user_ref" => user_ref})
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

  defp perform_delivery(messages) when is_list(messages) do
    Enum.map(messages, fn message ->
      Task.start(fn ->
        {channel_ref, new_msg} = Map.pop(message, :channel_ref)
        PubSubCore.deliver_to_channel(channel_ref, ProtocolMessage.to_protocol_message(new_msg))
      end)
    end)
  end

  defp perform_delivery({:ok, message}, %{"channel_ref" => channel_ref}) do
    Task.start(fn ->
      new_msg = message
      |> Map.drop(["channel_ref"])
      |> ProtocolMessage.to_protocol_message

      PubSubCore.deliver_to_channel(channel_ref, new_msg)
    end)
    {202, %{result: "Ok"}}
  end

  defp perform_delivery({:ok, message}, %{"app_ref" => app_ref}) do
    Task.start(fn ->
      new_msg = message
      |> Map.drop([:app_ref])
      |> ProtocolMessage.to_protocol_message
      PubSubCore.deliver_to_app_channels(app_ref, new_msg)
    end)

    {202, %{result: "Ok"}}
  end

  defp perform_delivery({:ok, message}, %{"user_ref" => user_ref}) do
    Task.start(fn ->
      new_msg = message
      |> Map.drop([:user_ref])
      |> ProtocolMessage.to_protocol_message
      PubSubCore.deliver_to_user_channels(user_ref, new_msg)
    end)

    {202, %{result: "Ok"}}
  end

  defp perform_delivery(e = {:error, :invalid_message}, _) do
    {400, e}
  end

  @spec batch_separate_messages([map()]) :: {[map()], [map()]}
  defp batch_separate_messages(messages) do
    {valid, invalid} = Enum.take(messages, 10)
    |> Enum.map(fn message ->
      case assert_deliver_request(message) do
        {:ok, _} ->
          {:ok, message}
        {:error, _} ->
          {:error, {message, :invalid_message}}
      end
    end)
    |> Enum.split_with(fn {outcome, _detail} -> case outcome do
        :ok -> true
        :error -> false
      end
    end)

    {
      Enum.map(valid, fn {:ok, message} -> message end),
      Enum.map(invalid, fn {:error, {message, _}} -> message end)
    }
  end

  defp batch_build_response({valid, invalid}, messages, conn) do
    original_size = length(messages)
    l_valid = length(valid)
    l_invalid = length(invalid)
    case {l_valid, l_invalid} do
      {0, 0} ->
        build_and_send_response({400, nil}, conn)
      {0, i} when i > 0 ->
        build_and_send_response({400, %{result: "invalid-messages",
        accepted_messages: 0,
        discarded_messages: i,
        discarded: invalid}}, conn)
      {v, 0} ->
        procesed = l_valid + l_invalid
        discarded = original_size - procesed
        msg = case discarded do
          0 -> %{result: "Ok"}
          _ -> %{result: "partial-success",
            accepted_messages: v,
            discarded_messages: discarded,
            discarded: Enum.drop(messages, 10)}
        end
        build_and_send_response({202, msg}, conn)
      {v, i} ->
        build_and_send_response({202, %{result: "partial-success",
          accepted_messages: v,
          discarded_messages: i,
          discarded: invalid}}, conn)
    end
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

  defp get_header(conn, name) do
    conn.req_headers
    |> Enum.filter(fn {key, _} -> key == name end)
    |> Enum.map(fn {_, value} -> value end)
    |> List.first()
  end

end
