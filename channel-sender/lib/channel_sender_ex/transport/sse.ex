defmodule ChannelSenderEx.Transport.Sse do
  @behaviour :cowboy_handler

  require Logger

  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
  alias ChannelSenderEx.Core.RulesProvider
  alias ChannelSenderEx.Core.ChannelRegistry
  alias ChannelSenderEx.Transport.Encoders.JsonEncoder
  import ChannelSenderEx.Core.Retry.ExponentialBackoff, only: [execute: 5]

  # bad request, invalid request received and data received is not valid
  @invalid_request_code "3006"

  # unauthorized, invalid secret code
  @invalid_secret_code "3008"

  # bad request, invalid or unexistent channel reference
  @invalid_channel_code "3050"

  @channel_key "channel"
  @channel_secret "authorization"

  def init(req, state) do
    case :cowboy_req.method(req) do
      "OPTIONS" -> handle_options(req, state)
      "GET" ->
        Logger.debug("Sse init #{inspect(self())}, REQ: #{inspect(req)}")
        result = get_relevant_request_info(req)
        |> lookup_channel_addr()
        |> authorize()
        case result do
          {:error, @invalid_request_code} ->
            req = invalid_request(req, 400, @invalid_request_code)
            {:ok, req, nil}
          {:error, @invalid_channel_code} ->
            req = invalid_request(req, 428, @invalid_channel_code)
            {:ok, req, nil}
          {:error, @invalid_secret_code } ->
            invalid_request(req, 401, @invalid_secret_code)
            {:ok, req, nil}
          {:error, nil} ->
            invalid_request(req, 500, "unknown error")
            {:ok, req, nil}
          :ok ->
            # Set headers for SSE
            headers = %{
              "content-type" => "text/event-stream",
              "cache-control" => "no-cache",
              "connection" => "keep-alive",
              "access-control-allow-origin" => "*",  # Allow all origins (change for security)
              "access-control-allow-methods" => "GET, OPTIONS",
              "access-control-allow-headers" => "content-type, authorization"
            }

            # Send initial response (200 OK with SSE headers)
            req = :cowboy_req.stream_reply(200, headers, req)

            # Start sending events asynchronously
            # spawn(fn -> stream_events(req) end)

            {:cowboy_loop, req, state}
        end
      _other -> {:ok, :cowboy_req.reply(405, req), state}  # 405 Method Not Allowed
    end
  end

  defp handle_options(req, state) do
    req = send_cors_headers(req)
    req = :cowboy_req.reply(204, req)  # 204 No Content for preflight responses
    {:ok, req, state}
  end

  # Adds CORS headers to the response
  defp send_cors_headers(req) do
    headers = %{
      "access-control-allow-origin" => "*",  # Allow all origins (change for security)
      "access-control-allow-methods" => "GET, OPTIONS",
      "access-control-allow-headers" => "content-type, authorization"
    }
    :cowboy_req.set_resp_headers(headers, req)
  end

  def info({:deliver_msg, {pid, ref}, message = {msg_id, _, _, _, _}}, req, state) do
    {:ok, {:text, response}} = JsonEncoder.encode_message(message)
    send_event(req, response)
    send(pid, {:ack, ref, msg_id})
    {:ok, req, state}
  end

  def info(:terminate_socket, req, state) do
    # ! check if we need to do something with the new_socket_pid
    Logger.info("Sse for channel xxxxxx : received terminate_socket message")
    {:ok, req, state}
  end

  defp send_event(req, message) do
    sse_data = "data: #{message}\n\n"
    Logger.debug("Sse send_event: #{sse_data}")
    case :cowboy_req.stream_body(sse_data, :nofin, req) do
      :ok -> :ok
      {:error, _} = error -> error  # Handle closed connection
    end
  end

  defp get_relevant_request_info(req) do
    :cowboy_req.read_body(req)
    with {@channel_key, channel} <- extract_channel_ref(req),
        {@channel_secret, secret} <- extract_secret(req) do
        {channel, secret}
    else
      {:error, code} = e ->
        Logger.error("e: #{inspect(e)}")
        {:error, code}
    end
  end

  defp extract_channel_ref(req) do
    case :lists.keyfind(@channel_key, 1, :cowboy_req.parse_qs(req)) do
      {@channel_key, channel} = resp ->
        IO.inspect(resp, label: "extract_channel_ref 1")
        resp
      x ->
        IO.inspect(x, label: "extract_channel_ref")
        Logger.error("SSe Invalid request, channel_ref not found")
        {:error, @invalid_request_code}
    end
  end

  defp extract_secret(req) do
    case Map.get(:cowboy_req.headers(req), "authorization") do
      nil ->
        Logger.error("SSe Invalid request, authorization header not found")
        {:error, @invalid_secret_code}
      value -> {@channel_secret, List.last(String.split(value))}
    end
  end

  defp authorize(res = {:error, _code}) do
    res
  end

  defp authorize({channel, secret}) do
    case ChannelAuthenticator.authorize_channel(channel, secret) do
      {:ok, _application, _user_ref} ->
        _monitor_ref = notify_connected(channel)
        :ok

      :unauthorized ->
        Logger.error("LongPoll unable to authorize connection. Error: #{@invalid_secret_code}-invalid token for channel #{channel}")
        {:error, @invalid_secret_code}
    end
  end

  defp notify_connected(channel) do
    Logger.debug("Long poll for channel #{channel} will be connected")
    socket_event_bus = get_param(:socket_event_bus, nil)
    ch_pid = socket_event_bus.notify_event({:connected, channel}, self())
    Process.monitor(ch_pid)
  end

  defp lookup_channel_addr(e = {:error, _code}) do
    e
  end

  defp lookup_channel_addr(req = {channel_ref, _secret}) do
    action_fn = fn _ -> check_channel_registered(req) end
    # retries 3 times the lookup of the channel reference (useful when running as a cluster with several nodes)
    # with a backoff strategy of 100ms initial delay and max of 500ms delay.
    execute(100, 500, 3, action_fn, fn ->
      Logger.error("Long poll unable to start. channel_ref process does not exist yet, ref: #{inspect(channel_ref)}")
      {:error, @invalid_channel_code}
    end)
  end

  defp check_channel_registered(req = {channel_ref, _secret}) do
    case ChannelRegistry.lookup_channel_addr(channel_ref) do
      :noproc ->
        Logger.warning("LongPoll, channel #{channel_ref} not found, retrying...")
        :retry
      _ ->
        req
    end
  end

  defp get_param(param, def) do
    RulesProvider.get(param)
  rescue
    _e -> def
  end

  @compile {:inline, invalid_request: 3}
  defp invalid_request(req, status, error_code) do
    req = send_cors_headers(req)
    :cowboy_req.reply(status,
      %{"content-type" => "application/json",
        "x-error-code" => error_code},
      Jason.encode!(%{"error" => error_code}), req)
  end
end
