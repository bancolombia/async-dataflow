defmodule ChannelSenderEx.Transport.Rest.RestController do
  @moduledoc """
  Endpoints for internal channel creation and channel message delivery orders
  """
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.PubSub.PubSubCore
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
  alias Plug.Conn.Query
  alias OpenTelemetry.Tracer

  use Plug.Router
  use Plug.ErrorHandler

  require Logger

  # @metadata_headers_max 3
  # @metadata_headers_prefix "x-meta-"

  plug(OpentelemetryPlug.Propagation)
  plug(Plug.Telemetry, event_prefix: [:channel_sender_ex, :plug])
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
  post("/ext/channel/deliver_batch", do: deliver_message(conn))
  delete("/ext/channel", do: close_channel(conn))
  match(_, do: send_resp(conn, 404, "Route not found."))

  defp create_channel(conn) do
    # collect metadata from headers, up to 3 metadata fields
    # metadata = conn.req_headers
    # |> Enum.filter(fn {key, _} -> String.starts_with?(key, @metadata_headers_prefix) end)
    # |> Enum.map(fn {key, value} -> {String.replace(key, @metadata_headers_prefix, ""), String.slice(value, 0, 50)} end)
    # |> Enum.take(@metadata_headers_max)
    add_trace_metadata(conn.body_params)
    route_create(conn.body_params, [], conn)
  end

  @spec route_create(map(), list(), Plug.Conn.t()) :: Plug.Conn.t()
  defp route_create(
         message = %{
           application_ref: application_ref,
           user_ref: user_ref
         },
         metadata,
         conn
       ) do
    is_valid =
      message
      |> Enum.all?(fn {_, value} -> is_binary(value) and value != "" end)

    case is_valid do
      true ->
        {channel_ref, channel_secret} =
          ChannelAuthenticator.create_channel(application_ref, user_ref, metadata)

        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(
          200,
          Jason.encode!(%{channel_ref: channel_ref, channel_secret: channel_secret})
        )

      false ->
        invalid_body(conn)
    end
  end

  defp route_create(_body, _metadata, conn) do
    invalid_body(conn)
  end

  defp close_channel(conn) do
    params =
      conn.query_string
      |> Query.decode()

    add_trace_metadata(params)
    channel = Map.get(params, "channel_ref", nil)

    case channel do
      nil ->
        invalid_body(conn)

      "" ->
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

  defp route_deliver(
         _body = %{
           messages: messages
         },
         conn
       ) do
    # takes N first messages and separates them into valid and invalid messages
    {valid_messages, invalid_messages} = batch_separate_messages(messages)

    valid_messages
    |> perform_delivery

    batch_build_response({valid_messages, invalid_messages}, messages, conn)
  end

  defp route_deliver(
         message = %{
           channel_ref: channel_ref,
           message_id: _message_id,
           correlation_id: _correlation_id,
           message_data: _message_data,
           event_name: _event_name
         },
         conn
       ) do
    assert_deliver_request(message)
    |> perform_delivery(%{"channel_ref" => channel_ref})
    |> build_and_send_response(conn)
  end

  defp route_deliver(
         message = %{
           app_ref: app_ref,
           message_id: _message_id,
           correlation_id: _correlation_id,
           message_data: _message_data,
           event_name: _event_name
         },
         conn
       ) do
    assert_deliver_request(message)
    |> perform_delivery(%{"app_ref" => app_ref})
    |> build_and_send_response(conn)
  end

  defp route_deliver(
         message = %{
           user_ref: user_ref,
           message_id: _message_id,
           correlation_id: _correlation_id,
           message_data: _message_data,
           event_name: _event_name
         },
         conn
       ) do
    assert_deliver_request(message)
    |> perform_delivery(%{"user_ref" => user_ref})
    |> build_and_send_response(conn)
  end

  defp route_deliver(_, conn), do: invalid_body(conn)

  # """
  # Asserts that the message is a valid delivery request
  # """
  @spec assert_deliver_request(map()) :: {:ok, map()} | {:error, :invalid_message}
  defp assert_deliver_request(message) do
    # Check if minimal fields are present and not nil
    add_trace_metadata(message)

    result =
      message
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
      new_msg = ProtocolMessage.to_protocol_message(message)

      PubSubCore.deliver_to_channel(channel_ref, new_msg)
    end)

    {202, %{result: "Ok"}}
  end

  defp perform_delivery({:ok, message}, %{"app_ref" => app_ref}) do
    Task.start(fn ->
      new_msg = ProtocolMessage.to_protocol_message(message)
      PubSubCore.deliver_to_app_channels(app_ref, new_msg)
    end)

    {202, %{result: "Ok"}}
  end

  defp perform_delivery({:ok, message}, %{"user_ref" => user_ref}) do
    Task.start(fn ->
      new_msg = ProtocolMessage.to_protocol_message(message)
      PubSubCore.deliver_to_user_channels(user_ref, new_msg)
    end)

    {202, %{result: "Ok"}}
  end

  defp perform_delivery(e = {:error, :invalid_message}, _) do
    {400, e}
  end

  @spec batch_separate_messages([map()]) :: {[map()], [map()]}
  defp batch_separate_messages(messages) do
    {valid, invalid} =
      Enum.take(messages, 10)
      |> Enum.map(fn message ->
        case assert_deliver_request(message) do
          {:ok, _} ->
            {:ok, message}

          {:error, _} ->
            {:error, {message, :invalid_message}}
        end
      end)
      |> Enum.split_with(fn {outcome, _detail} ->
        case outcome do
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
        build_and_send_response(
          {400,
           %{
             result: "invalid-messages",
             accepted_messages: 0,
             discarded_messages: i,
             discarded: invalid
           }},
          conn
        )

      {v, 0} ->
        processed = l_valid + l_invalid
        discarded = original_size - processed

        msg =
          case discarded do
            0 ->
              %{result: "Ok"}

            _ ->
              %{
                result: "partial-success",
                accepted_messages: v,
                discarded_messages: discarded,
                discarded: Enum.drop(messages, 10)
              }
          end

        build_and_send_response({202, msg}, conn)

      {v, i} ->
        build_and_send_response(
          {202,
           %{
             result: "partial-success",
             accepted_messages: v,
             discarded_messages: i,
             discarded: invalid
           }},
          conn
        )
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
    response =
      case conn.status do
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

  defp add_trace_metadata(params) do
    metadata = %{
      "user_ref" => params[:user_ref],
      "app_ref" => params[:application_ref] || params[:app_ref],
      "channel_ref" => params[:channel_ref],
      "msg" => params[:message_id]
    }

    Enum.each(metadata, fn {k, v} ->
      if v, do: Tracer.set_attribute("adf." <> k, v)
    end)
  end
end
