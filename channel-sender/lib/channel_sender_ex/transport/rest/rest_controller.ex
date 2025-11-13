defmodule ChannelSenderEx.Transport.Rest.RestController do
  @moduledoc """
  Endpoints for internal channel creation and channel message delivery orders
  """
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.PubSub.PubSubCore
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
  alias ChannelSenderEx.Utils.ChannelMetrics
  require OpenTelemetry.Ctx, as: Ctx
  require OpenTelemetry.Tracer, as: Tracer
  alias Plug.Conn.Query

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
  get("/ext/channel/count", do: get_channel_count(conn))
  post("/ext/channel/create", do: create_channel(conn))
  post("/ext/channel/deliver_message", do: deliver_message(conn))
  post("/ext/channel/deliver_batch", do: deliver_message(conn))
  post("/ext/channel/deliver_two_events", do: deliver_two_events(conn))
  delete("/ext/channel", do: close_channel(conn))
  match(_, do: send_resp(conn, 404, "Route not found."))

  defp create_channel(conn) do
    # collect metadata from headers, up to 3 metadata fields
    # metadata = conn.req_headers
    # |> Enum.filter(fn {key, _} -> String.starts_with?(key, @metadata_headers_prefix) end)
    # |> Enum.map(fn {key, value} -> {String.replace(key, @metadata_headers_prefix, ""), String.slice(value, 0, 50)} end)
    # |> Enum.take(@metadata_headers_max)
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

        params = %{application_ref: application_ref, user_ref: user_ref, channel_ref: channel_ref}
        add_trace_metadata(params)

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
    parent_ctx = Ctx.get_current()

    Enum.map(messages, fn message ->
      Task.start(fn -> perform_delivery_deliver_message(message, parent_ctx) end)
    end)
  end

  defp perform_delivery_deliver_message(message, parent_ctx) do
    Ctx.attach(parent_ctx)
    span_ctx = Tracer.start_span("deliver_to_channel", %{parent: parent_ctx})
    Tracer.set_current_span(span_ctx)
    {channel_ref, new_msg} = Map.pop(message, :channel_ref)

    res =
      PubSubCore.deliver_to_channel(
        channel_ref,
        ProtocolMessage.to_protocol_message(new_msg)
      )

    case res do
      :error ->
        Logger.warning("Channel #{inspect(channel_ref)} not found, message delivery failed")
        Tracer.set_status(OpenTelemetry.status(:error, "Channel not found"))

      _ ->
        :ok
    end

    Tracer.end_span()
    res
  end

  defp perform_delivery({:ok, message}, %{"channel_ref" => channel_ref}) do
    parent_ctx = Ctx.get_current()

    Task.start(fn ->
      Ctx.attach(parent_ctx)
      span_ctx = Tracer.start_span("deliver_to_channel", %{parent: parent_ctx})
      Tracer.set_current_span(span_ctx)
      new_msg = ProtocolMessage.to_protocol_message(message)
      res = PubSubCore.deliver_to_channel(channel_ref, new_msg)
      Logger.debug("Delivering message to channel #{inspect(res)}")

      case res do
        :error ->
          Logger.warning("Channel #{inspect(channel_ref)} not found, message delivery failed")
          Tracer.set_status(OpenTelemetry.status(:error, "Channel not found"))

        _ ->
          :ok
      end

      Tracer.end_span()
      res
    end)

    {202, %{result: "Ok"}}
  end

  defp perform_delivery({:ok, message}, %{"app_ref" => app_ref}) do
    parent_ctx = Ctx.get_current()

    Task.start(fn ->
      Ctx.attach(parent_ctx)
      span_ctx = Tracer.start_span("deliver_to_app_channels", %{parent: parent_ctx})
      Tracer.set_current_span(span_ctx)
      new_msg = ProtocolMessage.to_protocol_message(message)
      res = PubSubCore.deliver_to_app_channels(app_ref, new_msg)

      cond do
        res.accepted_connected > 0 ->
          Tracer.add_event("deliver_message", %{
            state: :connected,
            detail: "Message delivered to connected socket"
          })

        res.accepted_waiting > 0 ->
          Tracer.add_event("deliver_message", %{
            state: :waiting,
            detail: "Message queued for socket connection"
          })

        res.accepted_connected == 0 and res.accepted_waiting == 0 ->
          Logger.warning("AppRef #{inspect(app_ref)} not found, message delivery failed")
          Tracer.set_status(OpenTelemetry.status(:error, "AppRef not found"))
      end

      Tracer.end_span()
      res
    end)

    {202, %{result: "Ok"}}
  end

  defp perform_delivery({:ok, message}, %{"user_ref" => user_ref}) do
    parent_ctx = Ctx.get_current()

    Task.start(fn ->
      Ctx.attach(parent_ctx)
      span_ctx = Tracer.start_span("deliver_to_user_channels", %{parent: parent_ctx})
      Tracer.set_current_span(span_ctx)
      new_msg = ProtocolMessage.to_protocol_message(message)
      res = PubSubCore.deliver_to_user_channels(user_ref, new_msg)
      Tracer.end_span()
      res
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

  defp deliver_two_events(conn) do
    route_deliver_two_events(conn.body_params, conn)
  end


  defp route_deliver_two_events(
         %{
           channel_ref: channel_ref,
           event_one: event_one,
           event_two: event_two
         },
         conn
       ) do
    add_trace_metadata(%{channel_ref: channel_ref})

    with {:ok, message_one} <- assert_deliver_request(event_one),
         {:ok, message_two} <- assert_deliver_request(event_two) do
      # Deliver first event
      perform_delivery_two_events(channel_ref, message_one, message_two)

      conn
      |> put_resp_header("content-type", "application/json")
      |> send_resp(202, Jason.encode!(%{result: "Ok", events_sent: 2}))
    else
      {:error, :invalid_message} ->
        invalid_body(conn)
    end
  end

  defp route_deliver_two_events(_, conn), do: invalid_body(conn)

  @spec perform_delivery_two_events(String.t(), map(), map()) :: :ok
  defp perform_delivery_two_events(channel_ref, message_one, message_two) do
    parent_ctx = Ctx.get_current()

    Task.start(fn ->
      Ctx.attach(parent_ctx)
      span_ctx = Tracer.start_span("deliver_two_events_to_channel", %{parent: parent_ctx})
      Tracer.set_current_span(span_ctx)

      # Convert to protocol messages
      protocol_msg_one = ProtocolMessage.to_protocol_message(message_one)
      protocol_msg_two = ProtocolMessage.to_protocol_message(message_two)

      # Deliver first event
      res_one = PubSubCore.deliver_to_channel(channel_ref, protocol_msg_one)

      Logger.debug(
        "Delivering first event to channel #{channel_ref}, result: #{inspect(res_one)}"
      )

      # Small delay to ensure order (optional, can be removed if not needed)
      Process.sleep(10)

      # Deliver second event
      res_two = PubSubCore.deliver_to_channel(channel_ref, protocol_msg_two)

      Logger.debug(
        "Delivering second event to channel #{channel_ref}, result: #{inspect(res_two)}"
      )

      case {res_one, res_two} do
        {:error, _} ->
          Logger.warning(
            "Channel #{inspect(channel_ref)} not found, first message delivery failed"
          )

          Tracer.set_status(OpenTelemetry.status(:error, "Channel not found for first event"))

        {_, :error} ->
          Logger.warning(
            "Channel #{inspect(channel_ref)} not found, second message delivery failed"
          )

          Tracer.set_status(OpenTelemetry.status(:error, "Channel not found for second event"))

        _ ->
          Tracer.add_event("deliver_two_events", %{
            detail: "Both events delivered successfully"
          })

          :ok
      end

      Tracer.end_span()
    end)

    :ok
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

  defp get_channel_count(conn) do
    count = ChannelMetrics.get_count()

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, Jason.encode!(%{total_channels: count}))
  end

  defp add_trace_metadata(params) do
    metadata = %{
      "user_ref" => unwrap_optional(params[:user_ref]),
      "app_ref" => params[:application_ref] || params[:app_ref],
      "channel_ref" => params[:channel_ref],
      "msg" => params[:message_id]
    }

    Enum.each(metadata, fn {k, v} ->
      if v, do: Tracer.set_attribute("adf." <> k, v)
    end)
  end

  defp unwrap_optional("Optional[" <> rest), do: String.trim_trailing(rest, "]")
  defp unwrap_optional(val), do: val
end
