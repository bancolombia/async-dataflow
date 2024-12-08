defmodule ChannelSenderEx.Transport.Socket do
  @moduledoc """
  Implements real time socket communications with cowboy
  """
  @behaviour :cowboy_websocket
  @channel_key "channel"

  # Error code to indicate a generic bad request
  @invalid_request_code "1006"

  # Error code to indicate bad request, specifically when
  # not providing a valid channel reference
  @invalid_channel_code "1007"

  @invalid_secret_code 1008

  require Logger
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.RulesProvider
  alias ChannelSenderEx.Core.ChannelRegistry
  alias ChannelSenderEx.Transport.Encoders.{BinaryEncoder, JsonEncoder}
  alias ChannelSenderEx.Core.PubSub.ReConnectProcess
  import ChannelSenderEx.Core.Retry.ExponentialBackoff, only: [execute: 5]

  @type channel_ref() :: String.t()
  @type application_ref() :: String.t()
  @type user_ref() :: String.t()
  @type ch_ref() :: reference()
  @type pending_bag() :: %{String.t() => {pid(), reference()}}
  @type context_data() :: {application_ref(), user_ref(), ch_ref()}
  @type protocol_encoder() :: atom()

  @type pre_operative_state ::
          {channel_ref(), :pre_auth, protocol_encoder()} | {channel_ref(), :unauthorized}
  @type operative_state ::
          {channel_ref(), :connected, protocol_encoder(), context_data(), pending_bag()}
  @type socket_state :: pre_operative_state() | operative_state()

  @impl :cowboy_websocket
  def init(req = %{method: "GET"}, opts) do
    init_result = get_relevant_request_info(req)
      |> lookup_channel_addr
      |> process_subprotocol_selection(req)

    case init_result do
      {:cowboy_websocket, _, _, _} = res ->
        res
      {:error, desc} ->
        :cowboy_req.reply(400, %{<<"x-error-code">> => desc}, req)
        {:ok, req, opts}
    end
  end

  defp get_relevant_request_info(req) do
    # extracts the channel key from the request query string
    case :lists.keyfind(@channel_key, 1, :cowboy_req.parse_qs(req)) do
      {@channel_key, channel} = resp when byte_size(channel) > 10 ->
        Logger.debug("Socket starting, parameters: #{inspect(resp)}")
        resp
      _ ->
        Logger.error("Socket unable to start. channel_ref not found in query string request.")
        {:error, @invalid_request_code}
    end
  end

  defp lookup_channel_addr(channel_ref) do
    action_fn = fn _ -> check_channel_registered(channel_ref) end
    # retries 3 times the lookup of the channel reference (useful when running as a cluster with several nodes)
    # with a backoff strategy of 100ms initial delay and max of 500ms delay.
    execute(100, 500, 3, action_fn, fn ->
      Logger.error("Socket unable to start. channel_ref process does not exist yet, ref: #{inspect(channel_ref)}")
      {:error, @invalid_channel_code}
    end)
  end

  defp check_channel_registered({@channel_key, channel_ref} = res) do
    case ChannelRegistry.lookup_channel_addr(channel_ref) do
      :noproc ->
        Logger.warning("Channel #{channel_ref} not found, retrying query...")
        :retry
      _ -> res
    end
  end

  defp check_channel_registered({:error, _desc} = res) do
    res
  end

  defp process_subprotocol_selection({@channel_key, channel}, req) do
    case :cowboy_req.parse_header("sec-websocket-protocol", req) do
      :undefined ->
        {:cowboy_websocket, req, _state = {channel, :pre_auth, Application.get_env(
          :channel_sender_ex,
          :message_encoder,
          ChannelSenderEx.Transport.Encoders.JsonEncoder
          )}, ws_opts()}

      sub_protocols ->
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
  end

  defp process_subprotocol_selection({:error, _} = err, _req) do
    Logger.error("Socket unable to start. Error: #{inspect(err)}")
    err
  end

  @impl :cowboy_websocket
  def websocket_init(state) do
    Logger.debug("Socket init #{inspect(state)}")
    {_commands = [], state}
  end

  @impl :cowboy_websocket
  def websocket_handle({:text, "Auth::" <> secret}, {channel, :pre_auth, encoder}) do
    case ChannelAuthenticator.authorize_channel(channel, secret) do
      {:ok, application, user_ref} ->
        monitor_ref = notify_connected(channel)

        {_commands = [auth_ok_frame(encoder)],
         {channel, :connected, encoder, {application, user_ref, monitor_ref}, %{}}}

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
  def websocket_handle({:text, "hb::" <> hb_seq}, state = {_, :connected, encoder, _, _}) do
    {_commands = [encoder.heartbeat_frame(hb_seq)], state}
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
    Logger.debug("Socket for channel #{channel} connected")

    socketEventBus = RulesProvider.get(:socket_event_bus)
    ch_pid = socketEventBus.notify_event({:connected, channel}, self())
    IO.inspect("Socket channel #{channel} to monitor #{inspect(ch_pid)}")
    Process.monitor(ch_pid)
  end

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
  def websocket_info({:DOWN, ref, :process, _pid, _cause}, state = {channel_ref, :connected, _, {_, _, ref}, _}) do
    Logger.warning("Socket for channel #{channel_ref} : spawning process for re-conection")
    spawn_monitor(ReConnectProcess, :start, [self(), channel_ref])
    {_commands = [], state}
  end

 @impl :cowboy_websocket
 def websocket_info({:DOWN, _ref, :process, _pid, :no_channel}, state = {channel_ref, :connected, _, {_, _, _ref}, _}) do
    Logger.debug("Socket info :DOWN #{inspect(state)} XXX1")
    spawn_monitor(ReConnectProcess, :start, [self(), channel_ref])
    {_commands = [], state}
 end

  @impl :cowboy_websocket
  def websocket_info(_message, state) do
    Logger.debug("Socket info #{inspect(state)} XXX0")
    {_commands = [], state}
  end

  @impl :cowboy_websocket
  def terminate(reason, _partial_req, state) do
    case state do
      {channel_ref, _, _, _, _} ->
        Logger.warning("Socket for channel #{channel_ref} terminated with reason: #{inspect(reason)}")
        :ok
      _ -> :ok
    end
  end

  @compile {:inline, auth_ok_frame: 1}
  defp auth_ok_frame(encoder), do: encoder.simple_frame("AuthOk")

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
