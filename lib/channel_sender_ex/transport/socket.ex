defmodule ChannelSenderEx.Transport.Socket do
  @moduledoc """
  Implements real time socket communications with cowboy
  """
  @behaviour :cowboy_websocket
  @channel_key "channel"
  @invalid_secret_code 1008
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.RulesProvider
  alias ChannelSenderEx.Transport.Encoders.{BinaryEncoder, JsonEncoder}

  @default_protocol_encoder Application.get_env(
                              :channel_sender_ex,
                              :message_encoder,
                              ChannelSenderEx.Transport.Encoders.JsonEncoder
                            )

  @type channel_ref() :: String.t()
  @type application_ref() :: String.t()
  @type user_ref() :: String.t()
  @type pending_bag() :: %{String.t() => {pid(), reference()}}
  @type context_data() :: {application_ref(), user_ref()}
  @type protocol_encoder() :: atom()

  @type pre_operative_state ::
          {channel_ref(), :pre_auth, protocol_encoder()} | {channel_ref(), :unauthorized}
  @type operative_state ::
          {channel_ref(), :connected, protocol_encoder(), context_data(), pending_bag()}
  @type socket_state :: pre_operative_state() | operative_state()

  @impl :cowboy_websocket
  def init(req = %{method: "GET"}, _opts) do
    case :lists.keyfind(@channel_key, 1, :cowboy_req.parse_qs(req)) do
      {@channel_key, channel} when byte_size(channel) > 10 ->
        case :cowboy_req.parse_header("sec-websocket-protocol", req) do
          :undefined ->
            {:cowboy_websocket, req, _state = {channel, :pre_auth, @default_protocol_encoder},
             ws_opts()}

          sub_protocols ->
            #            IO.inspect(sub_protocols)
            {encoder, req} =
              case Enum.member?(sub_protocols, "binary_flow") do
                true ->
                  {BinaryEncoder,
                   :cowboy_req.set_resp_header("sec-websocket-protocol", "binary_flow", req)}

                false ->
                  {JsonEncoder,
                   :cowboy_req.set_resp_header("sec-websocket-protocol", "json_flow", req)}
              end

            {:cowboy_websocket, req, _state = {channel, :pre_auth, encoder}, ws_opts()}
        end

      _ ->
        req = :cowboy_req.reply(400, req)
        {:ok, req, _state = []}
    end
  end

  @impl :cowboy_websocket
  def websocket_init(state) do
    #    IO.inspect({:init, state})
    IO.puts("Connected with params: #{inspect(state)}")
    {_commands = [], state}
  end

  @impl :cowboy_websocket
  def websocket_handle({:text, "Auth::" <> secret}, {channel, :pre_auth, encoder}) do
    case ChannelAuthenticator.authorize_channel(channel, secret) do
      {:ok, application, user_ref} ->
        notify_connected(channel)

        {_commands = [auth_ok_frame()],
         {channel, :connected, encoder, {application, user_ref}, %{}}}

      :unauthorized ->
        {_commands = [{:close, @invalid_secret_code, "Invalid token for channel"}],
         {channel, :unauthorized}}
    end
  end

  @impl :cowboy_websocket
  def websocket_handle({:text, "Ack::" <> message_id}, state) do
    case remove_pending(state, message_id) do
      {nil, new_state} ->
        {[], new_state}

      {{pid, ref}, new_state} ->
        send(pid, {:ack, ref, message_id})
        {[], new_state}
    end
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

  @compile {:inline, notify_connected: 1}
  defp notify_connected(channel) do
    socketEventBus = RulesProvider.get(:socket_event_bus)
    socketEventBus.notify_event({:connected, channel}, self())
  end

  @compile {:inline, heartbeat_frame: 1}
  @spec heartbeat_frame(String.t()) :: iolist()
  defp heartbeat_frame(hb_seq), do: ["[\"\", \"", hb_seq, "\", \":hb\", \"\"]"]

  @compile {:inline, set_pending: 2}
  defp set_pending(state, new_pending), do: :erlang.setelement(5, state, new_pending)

  @compile {:inline, remove_pending: 2}
  defp remove_pending(state = {_, :connected, _, _, pending}, message_id) do
    case Map.pop(pending, message_id) do
      {nil, _} -> {nil, state}
      {elem, new_pending} -> {elem, set_pending(state, new_pending)}
    end
  end

  @impl :cowboy_websocket
  def websocket_info(
        {:deliver_msg, from = {pid, ref}, message},
        state = {_, :connected, encoder, _, pending_messages}
      ) do
    message_id = ProtocolMessage.message_id(message)

    case encoder.encode_message(message) do
      {:ok, encoded} ->
        new_state = state |> set_pending(Map.put(pending_messages, message_id, from))
        {_commands = [encoded], new_state}

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
  def terminate(_reason, _partial_req, _state) do
    #    IO.inspect(%{terminate_reason: reason, req: partial_req, state: state})
    :ok
  end

  @compile {:inline, auth_ok_frame: 0}
  defp auth_ok_frame(), do: simple_frame("AuthOk")

  @compile {:inline, simple_frame: 1}
  defp simple_frame(event), do: {:text, "[\"\", \"\", \"#{event}\", \"\"]"}

  defp ws_opts() do
    %{
      idle_timeout: RulesProvider.get(:socket_idle_timeout),
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
