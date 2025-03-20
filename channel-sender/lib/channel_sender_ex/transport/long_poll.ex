defmodule ChannelSenderEx.Transport.LongPoll do
  @moduledoc false

  @behaviour :cowboy_handler

  require Logger

  alias ChannelSenderEx.Core.RulesProvider
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
  alias ChannelSenderEx.Transport.Encoders.JsonEncoder
  alias ChannelSenderEx.Transport.TransportSpec

  use TransportSpec, option: :long_poll

  def init(req, state) do
    case :cowboy_req.method(req) do
      "OPTIONS" -> handle_options(req, state)
      "POST" ->
        Logger.debug("LongPoll init #{inspect(self())}, REQ: #{inspect(req)}")
        result = get_relevant_request_info(req)
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
          :ok ->
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
      "access-control-allow-methods" => "GET, POST, OPTIONS",
      "access-control-allow-headers" => "content-type, authorization"
    }
    :cowboy_req.set_resp_headers(headers, req)
  end

  def info({:deliver_msg, {pid, ref}, message = {msg_id, _, _, _, _}}, req, _) do
    {:ok, {:text, response}} = JsonEncoder.encode_message(message)
    req = :cowboy_req.reply(200, %{"content-type" => "application/json"}, response, req)
    send(pid, {:ack, ref, msg_id})
    {:stop, req, nil}
  end

  def info(:timeout, req) do
    req = :cowboy_req.reply(204, %{}, "", req)  # No Content response
    {:stop, req, nil}
  end

  def handle(req, state) do
    #LongPollServer.add_listener(self())  # Register client
    Process.send_after(self(), :timeout, 30_000)  # 30-second timeout
    {:cowboy_loop, req, state}
  end

  defp get_relevant_request_info(req) do
    with {@channel_key, channel} <- get_channel_from_qs(req),
        {@channel_secret, secret} <- get_token_from_header(req) do
        {channel, secret}
    else
      {:error, code} = e ->
        Logger.error("LongPoll not valid data at request: #{inspect(e)}")
        {:error, code}
    end
  end

  defp authorize(res = {:error, _code}) do
    res
  end

  defp authorize({channel, secret}) do
    with {:ok, channel_pid} <- lookup_channel_addr(channel),
         {:ok, _application, _user_ref} <- ChannelAuthenticator.authorize_channel(channel, secret) do
          _monitor_ref = notify_connected(channel_pid)
          :ok
    else
      :unauthorized ->
        Logger.error("LongPoll unable to authorize connection. Error: #{@invalid_secret_code}-invalid token for channel #{channel}")
        {:error, @invalid_secret_code}

      {:error, _} = e ->
        Logger.error("LongPoll unable to authorize connection. Error: #{inspect(e)}")
        e
    end
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
