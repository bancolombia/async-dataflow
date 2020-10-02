defmodule ChannelSenderEx.Transport.Socket do
  @moduledoc """
  Implements real time socket communications with cowboy
  """
  @behaviour :cowboy_websocket
  @channel_key "channel"
  @invalid_secret_code 1008
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
  alias ChannelSenderEx.Core.ProtocolMessage

  @impl :cowboy_websocket
  def init(req = %{method: "GET"}, _opts) do
    case :lists.keyfind(@channel_key, 1, :cowboy_req.parse_qs(req)) do
      {@channel_key, channel} when byte_size(channel) > 10 ->
        {:cowboy_websocket, req, _state = {channel, :connecting}, ws_opts()}

      _ ->
        req = :cowboy_req.reply(400, req)
        {:ok, req, _state = []}
    end
  end

  @impl :cowboy_websocket
  def websocket_init({channel, :connecting}) do
    {_commands = [], {channel, :pre_auth}}
  end

  @impl :cowboy_websocket
  def websocket_handle({:text, "Auth::" <> secret}, {channel, :pre_auth}) do
    case ChannelAuthenticator.authorize_channel(channel, secret) do
      {:ok, application, user_ref} ->
        {_commands = [auth_ok_frame()], {channel, :connected, {application, user_ref}, %{}}}

      :unauthorized ->
        {_commands = [{:close, @invalid_secret_code, "Invalid token for channel"}],
         {channel, :unauthorized}}
    end
  end

  @impl :cowboy_websocket
  def websocket_handle({:text, "Ack::" <> message_id}, state = {_, :connected, _, pending}) do
    new_state =
      case Map.pop(pending, message_id) do
        {nil, _} ->
          state

        {_from = {pid, ref}, new_pending} ->
          send(pid, {:ack, ref, message_id})
          state |> set_pending(new_pending)
      end

    {[], new_state}
  end

  @impl :cowboy_websocket
  def websocket_handle({:text, "hb::" <> hb_seq}, state) do
    {_commands = [{:text, heartbeat_frame(hb_seq)}], state}
  end

  @impl :cowboy_websocket
  def websocket_handle({:text, data}, state) do
    # [{text | binary | close | ping | pong, iodata()}]
    {_commands = [{:text, "Echo: " <> data}], state}
  end

  @impl :cowboy_websocket
  def websocket_handle(_message, state) do
    {_commands = [], state}
  end

  @compile {:inline, heartbeat_frame: 1}
  @spec heartbeat_frame(String.t()) :: iolist()
  defp heartbeat_frame(hb_seq), do: ["[\"\", \"", hb_seq, "\", \":hb\", \"\"]"]

  @compile {:inline, set_pending: 2}
  defp set_pending(state, new_pending), do: :erlang.setelement(4, state, new_pending)

  @impl :cowboy_websocket
  def websocket_info(
        {from = {pid, ref}, message},
        state = {_, :connected, _, pending_messages}
      ) do
    message_id = ProtocolMessage.message_id(message)

    case Jason.encode(ProtocolMessage.to_socket_message(message)) do
      {:ok, encoded} ->
        new_state = state |> set_pending(Map.put(pending_messages, message_id, from))
        {_commands = [{:text, encoded}], new_state}

      {:error, error} ->
        send(pid, {:non_retry_error, error, ref, message_id})
        {_commands = [], state}
    end
  end

  @impl :cowboy_websocket
  def websocket_info(_message, state) do
    {_commands = [], state}
  end

  @impl :cowboy_websocket
  def terminate(reason, partial_req, state) do
    IO.inspect(%{terminate_reason: reason, req: partial_req, state: state})
    :ok
  end

  @compile {:inline, auth_ok_frame: 0}
  defp auth_ok_frame(), do: simple_frame("AuthOk")

  @compile {:inline, simple_frame: 1}
  defp simple_frame(event), do: {:text, "[\"\", \"\", \"#{event}\", \"\"]"}

  defp ws_opts() do
    %{
      idle_timeout: 60000,
      #      active_n: 5,
      #      compress: false,
      #      deflate_opts: %{},
      max_frame_size: 1024,
      # Disable in pdn
      validate_utf8: true,
      # Usefull to save space avoiding to save all request info
      req_filter: fn %{qs: qs, peer: peer} -> {qs, peer} end
    }
  end
end
