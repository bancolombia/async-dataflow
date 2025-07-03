defmodule ChannelSenderEx.Transport.Sse do
  @moduledoc false

  @behaviour :cowboy_handler

  require Logger
  require OpenTelemetry.Tracer, as: Tracer

  alias ChannelSenderEx.Core.ChannelSupervisor
  alias ChannelSenderEx.Core.PubSub.ReConnectProcess
  alias ChannelSenderEx.Core.RulesProvider
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
  alias ChannelSenderEx.Transport.Encoders.JsonEncoder
  alias ChannelSenderEx.Transport.TransportSpec
  alias ChannelSenderEx.Utils.CustomTelemetry

  use TransportSpec, option: :sse

  def init(req, state) do
    case :cowboy_req.method(req) do
      "OPTIONS" ->
        handle_options(req, state)

      "GET" ->
        Logger.debug("Sse init #{inspect(self())}, REQ: #{inspect(req)}")

        result =
          get_relevant_request_info(req)
          |> authorize()

        case result do
          {:error, @invalid_request_code} ->
            req = invalid_request(req, 400, @invalid_request_code)
            Tracer.add_event("Auth", %{"status" => "bad request", "reason" => "invalid_request"})
            {:ok, req, nil}

          {:error, @invalid_channel_code} ->
            req = invalid_request(req, 428, @invalid_channel_code)

            Tracer.add_event("Auth", %{
              "status" => "precondition required",
              "reason" => "invalid_channel"
            })

            {:ok, req, nil}

          {:error, @invalid_secret_code} ->
            invalid_request(req, 401, @invalid_secret_code)
            Tracer.add_event("Auth", %{"status" => "unauthorized", "reason" => "invalid_token"})
            {:ok, req, nil}

          {:error, nil} ->
            invalid_request(req, 500, "unknown error")
            Tracer.add_event("Auth", %{"status" => "internal error", "reason" => "unknown_error"})
            {:ok, req, nil}

          :ok ->
            # Set headers for SSE
            headers = %{
              "content-type" => "text/event-stream",
              "cache-control" => "no-cache",
              "connection" => "keep-alive",
              # Allow all origins (change for security)
              "access-control-allow-origin" => "*",
              "access-control-allow-methods" => "GET, OPTIONS",
              "access-control-allow-headers" => "content-type, authorization"
            }

            # Send initial response (200 OK with SSE headers)
            req = :cowboy_req.stream_reply(200, headers, req)
            Tracer.add_event("Auth", %{"status" => "success"})
            {:cowboy_loop, req, state}
        end

      # 405 Method Not Allowed
      _other ->
        {:ok, :cowboy_req.reply(405, req), state}
    end
  end

  defp handle_options(req, state) do
    req = send_cors_headers(req)
    # 204 No Content for preflight responses
    req = :cowboy_req.reply(204, req)
    {:ok, req, state}
  end

  # Adds CORS headers to the response
  defp send_cors_headers(req) do
    headers = %{
      # Allow all origins (change for security)
      "access-control-allow-origin" => "*",
      "access-control-allow-methods" => "GET, OPTIONS",
      "access-control-allow-headers" => "content-type, authorization"
    }

    :cowboy_req.set_resp_headers(headers, req)
  end

  def info({:deliver_msg, {pid, ref}, message = {msg_id, _, _, _, _}}, req, state) do
    {:ok, {:text, response}} = JsonEncoder.encode_message(message)
    send_event(req, response)
    # send ack
    Process.send_after(self(), {:ack, ref, msg_id, pid}, 100)
    Tracer.add_event("Deliver", %{"msg" => msg_id})
    {:ok, req, state}
  end

  def info({:ack, ref, msg_id, chpid}, req, state) do
    send(chpid, {:ack, ref, msg_id})
    Tracer.add_event("Ack", %{"msg" => msg_id})
    {:ok, req, state}
  end

  def info(:terminate_socket, req, state) do
    ch =
      case get_channel_from_qs(req) do
        {:error, _} -> ""
        val -> val
      end

    Logger.debug(fn -> "Sse for channel [#{inspect(ch)}] : received terminate_socket message" end)
    #    CustomTelemetry.end_span("terminate")
    {:ok, req, state}
  end

  def info({:DOWN, ref, :process, pid, cause}, req, state) do
    {_, channel_ref} = get_channel_from_qs(req)

    case cause do
      :normal ->
        Logger.info(fn ->
          "SSE #{inspect(self())} for channel #{channel_ref}. Related process #{inspect(ref)} down normally."
        end)

        #        CustomTelemetry.end_span("normal")
        {:ok, req, state}

      _ ->
        Logger.warning("""
          SSE #{inspect(self())} for channel #{channel_ref}. Related Process #{inspect(ref)}
          received DOWN message: #{inspect({ref, pid, cause})}. Spawning process for re-conection
        """)

        #        Tracer.set_status(OpenTelemetry.status(:error, "#{inspect(cause)}"))
        #        CustomTelemetry.end_span("other")

        ReConnectProcess.start(self(), channel_ref, :sse,
          min_backoff: 50,
          max_backoff: 2000,
          max_retries: 5
        )

        {:ok, req, state}
    end
  end

  def info({:monitor_channel, channel_ref, new_pid}, req, state) do
    Logger.debug(fn ->
      "SSE #{inspect(self())} for channel #{channel_ref} : channel process found for re-conection: #{inspect(new_pid)}"
    end)

    {:ok, req, state}
  end

  defp send_event(req, message) do
    sse_data = "data: #{message}\n\n"
    :cowboy_req.stream_body(sse_data, :nofin, req)
  end

  defp get_relevant_request_info(req) do
    with {@channel_key, channel} <- get_channel_from_qs(req),
         {@channel_secret, secret} <- get_token_from_header(req) do
      span = CustomTelemetry.start_span(:sse, req, channel)
      Tracer.set_current_span(span)
      {channel, secret}
    else
      {:error, code} = e ->
        Logger.error("e: #{inspect(e)}")
        {:error, code}
    end
  end

  defp authorize(res = {:error, _code}) do
    res
  end

  defp authorize({channel, secret}) do
    with {:ok, application, user_ref} <- ChannelAuthenticator.authorize_channel(channel, secret),
         :ok <- ensure_channel_exists_and_notify_socket(channel, application, user_ref) do
      CustomTelemetry.execute_custom_event([:adf, :sse, :connection], %{count: 1})
      :ok
    else
      :unauthorized ->
        Logger.error(
          "Sse unable to authorize connection. Error: #{@invalid_secret_code}-invalid token for channel #{channel}"
        )

        {:error, @invalid_secret_code}

      {:error, _} = e ->
        Logger.error("Sse unable to authorize connection. Error: #{inspect(e)}")
        e
    end
  end

  defp ensure_channel_exists_and_notify_socket(channel, application, user_ref) do
    args = {channel, application, user_ref, []}

    case ChannelSupervisor.start_channel_if_not_exists(args) do
      {:ok, pid} ->
        _monitor_ref = notify_connected(pid, :sse)
        :ok

      {:error, reason} = e ->
        Logger.error(fn ->
          "Channel #{channel} not exists and unable to start. Reason: #{inspect(reason)}"
        end)

        Tracer.set_status(OpenTelemetry.status(:error, "#{inspect(reason)}"))
        CustomTelemetry.end_span("channel_not_exists")

        e
    end
  end

  @compile {:inline, invalid_request: 3}
  defp invalid_request(req, status, error_code) do
    CustomTelemetry.execute_custom_event([:adf, :sse, :badrequest], %{count: 1}, %{
      status: status,
      code: error_code
    })

    req = send_cors_headers(req)

    :cowboy_req.reply(
      status,
      %{"content-type" => "application/json", "x-error-code" => error_code},
      Jason.encode!(%{"error" => error_code}),
      req
    )
  end
end
