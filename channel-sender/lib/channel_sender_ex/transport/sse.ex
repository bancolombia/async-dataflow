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
    Process.flag(:trap_exit, true)

    case :cowboy_req.method(req) do
      "OPTIONS" ->
        handle_options(req, state)

      "GET" ->
        Logger.debug("Sse init #{inspect(self())}, REQ: #{inspect(req)}")

        result =
          get_relevant_request_info(req)
          |> authorize()

        case result do
          {:error, @invalid_request_code, span} ->
            req = invalid_request(req, 400, @invalid_request_code)
            Tracer.set_current_span(span)
            Tracer.add_event("Auth", %{"status" => "bad request", "reason" => "invalid_request"})
            CustomTelemetry.end_span("bad_request")
            {:ok, req, nil}

          {:error, @invalid_channel_code, span} ->
            req = invalid_request(req, 428, @invalid_channel_code)
            Tracer.set_current_span(span)

            Tracer.add_event("Auth", %{
              "status" => "precondition required",
              "reason" => "invalid_channel"
            })

            CustomTelemetry.end_span("invalid_channel")
            {:ok, req, nil}

          {:error, @invalid_secret_code, span} ->
            invalid_request(req, 401, @invalid_secret_code)
            Tracer.set_current_span(span)
            Tracer.add_event("Auth", %{"status" => "unauthorized", "reason" => "invalid_token"})
            CustomTelemetry.end_span("unauthorized")
            {:ok, req, nil}

          {:error, nil, span} ->
            invalid_request(req, 500, "unknown error")
            Tracer.set_current_span(span)
            Tracer.add_event("Auth", %{"status" => "internal error", "reason" => "unknown_error"})
            CustomTelemetry.end_span("unknown_error")
            {:ok, req, nil}

          {:ok, span} ->
            headers = %{
              "content-type" => "text/event-stream",
              "cache-control" => "no-cache",
              "connection" => "keep-alive",
              "access-control-allow-origin" => "*",
              "access-control-allow-methods" => "GET, OPTIONS",
              "access-control-allow-headers" => "content-type, authorization"
            }

            Tracer.set_current_span(span)
            Tracer.add_event("Auth", %{"status" => "success"})
            req = :cowboy_req.stream_reply(200, headers, req)
            {:cowboy_loop, req, Map.put(ensure_map(state), :span, span)}
        end

      _other ->
        {:ok, :cowboy_req.reply(405, req), state}
    end
  end

  defp ensure_map(state) when is_list(state), do: %{}
  defp ensure_map(state) when is_map(state), do: state

  defp handle_options(req, state) do
    req = send_cors_headers(req)
    req = :cowboy_req.reply(204, req)
    {:ok, req, state}
  end

  defp send_cors_headers(req) do
    headers = %{
      "access-control-allow-origin" => "*",
      "access-control-allow-methods" => "GET, OPTIONS",
      "access-control-allow-headers" => "content-type, authorization"
    }

    :cowboy_req.set_resp_headers(headers, req)
  end

  def info({:deliver_msg, {pid, ref}, message = {msg_id, _, _, _, _}}, req, state) do
    {:ok, {:text, response}} = JsonEncoder.encode_message(message)
    send_event(req, response)
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
    Tracer.add_event("Terminate", %{"detail" => "received terminate_socket message"})
    CustomTelemetry.end_span("terminate_socket")
    {:ok, req, state}
  end

  def info({:DOWN, ref, :process, pid, cause}, req, state) do
    {_, channel_ref} = get_channel_from_qs(req)

    case cause do
      :normal ->
        Logger.info(fn ->
          "SSE #{inspect(self())} for channel #{channel_ref}. Related process #{inspect(ref)} down normally."
        end)

        Tracer.add_event("Down", %{"detail" => "normal shutdown with cause: #{inspect(cause)}"})
        {:ok, req, state}

      _ ->
        Logger.warning("""
          SSE #{inspect(self())} for channel #{channel_ref}. Related Process #{inspect(ref)}
          received DOWN message: #{inspect({ref, pid, cause})}. Spawning process for re-conection
        """)

        Tracer.add_event("Down", %{
          "detail" => "reconnect process started with cause: #{inspect(cause)}"
        })

        CustomTelemetry.end_span("down_process")

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

    Tracer.add_event("Monitor", %{
      "detail" => "channel process found for reconnection"
    })

    CustomTelemetry.end_span("reconnect_process")

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
      {channel, secret, span}
    else
      {:error, code} = e ->
        span = CustomTelemetry.start_span(:sse, req, nil)
        Logger.error("e: #{inspect(e)}")
        {:error, code, span}
    end
  end

  defp authorize({:error, code, span}), do: {:error, code, span}

  defp authorize({channel, secret, span}) do
    Tracer.set_current_span(span)

    with {:ok, application, user_ref} <- ChannelAuthenticator.authorize_channel(channel, secret),
         :ok <- ensure_channel_exists_and_notify_socket(channel, application, user_ref) do
      CustomTelemetry.execute_custom_event([:adf, :sse, :connection], %{count: 1})
      {:ok, span}
    else
      :unauthorized ->
        Logger.error(
          "Sse unable to authorize connection. Error: #{@invalid_secret_code}-invalid token for channel #{channel}"
        )

        CustomTelemetry.end_span("unauthorized")
        {:error, @invalid_secret_code, span}

      {:error, _} = e ->
        Logger.error("Sse unable to authorize connection. Error: #{inspect(e)}")
        Tracer.set_status(OpenTelemetry.status(:error, "#{inspect(e)}"))
        CustomTelemetry.end_span("other")
        {:error, elem(e, 1), span}
    end
  end

  def terminate(reason, _req, state) do
    state = ensure_map(state)

    case Map.get(state, :span) do
      nil ->
        :ok

      _span ->
        CustomTelemetry.end_span("sse_terminate")
        :ok
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
        CustomTelemetry.end_span("other")
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
