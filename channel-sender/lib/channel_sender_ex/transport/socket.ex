defmodule ChannelSenderEx.Transport.Socket do
  @moduledoc """
  Implements real time socket communications with cowboy
  """
  @behaviour :cowboy_websocket

  require Logger

  alias ChannelSenderEx.Core.ChannelRegistry
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.PubSub.ReConnectProcess
  alias ChannelSenderEx.Core.RulesProvider
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
  alias ChannelSenderEx.Transport.Encoders.{BinaryEncoder, JsonEncoder}
  alias ChannelSenderEx.Transport.TransportSpec
  alias ChannelSenderEx.Utils.CustomTelemetry

  use TransportSpec, option: :ws

  @type pre_operative_state ::
          {channel_ref(), :pre_auth, protocol_encoder()} | {channel_ref(), :unauthorized}
  @type operative_state ::
          {channel_ref(), :connected, protocol_encoder(), context_data(), pending_bag()}
  @type socket_state :: pre_operative_state() | operative_state()

  @impl :cowboy_websocket
  def init(req = %{method: "GET"}, opts) do
    init_result = get_relevant_request_info(req)
      |> process_subprotocol_selection(req)
    case init_result do
      {:cowboy_websocket, _, _, _} = res ->
        res
      {:error, desc} ->
        :cowboy_req.reply(400, %{<<"x-error-code">> => desc}, req)
        {:ok, req, opts}
    end
  end

  @impl :cowboy_websocket
  def websocket_init(state = {ref, _, _}) do
    Logger.debug("Socket init with pid: #{inspect(self())} starting... #{inspect(state)}")
    case lookup_channel_addr(ref) do
      {:ok, _pid} ->
        {_commands = [], state}
      {:error, desc} ->
        {_commands = [{:close, 1001, desc}], state}
    end
  end

  @impl :cowboy_websocket
  def websocket_handle({:text, "Auth::" <> secret}, {channel, :pre_auth, encoder}) do
    case ChannelAuthenticator.authorize_channel(channel, secret) do
      {:ok, application, user_ref} ->
        monitor_ref = notify_connected(channel)

        CustomTelemetry.execute_custom_event([:adf, :socket, :connection], %{count: 1})

        {_commands = [auth_ok_frame(encoder)],
         {channel, :connected, encoder, {application, user_ref, monitor_ref}, %{}}}

      :unauthorized ->

        CustomTelemetry.execute_custom_event([:adf, :socket, :badrequest],
        %{count: 1},
        %{request_path: "/ext/socket", status: 101, code: @invalid_secret_code})

        Logger.error("Socket unable to authorize connection. Error: #{@invalid_secret_code}-invalid token for channel #{channel}")
        {_commands = [{:close, 1001, <<@invalid_secret_code>>}],
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
  def websocket_info(:terminate_socket, state = {channel_ref, _, _, _, _}) do
    # ! check if we need to do something with the new_socket_pid
    Logger.info("Socket for channel #{channel_ref} : received terminate_socket message")
    {_commands = [{:close, 1001, <<@socket_replaced>>}], state}
  end

  @impl :cowboy_websocket
  def websocket_info({:DOWN, ref, proc, pid, cause}, state = {channel_ref, _, _, _, _}) do
    case cause do
      :normal ->
        Logger.info("Socket for channel #{channel_ref}. Related process #{inspect(ref)} down normally.")
        {_commands = [{:close, 1000, <<@normal_close_code>>}], state}
      _ ->
        Logger.warning("""
          Socket for channel #{channel_ref}. Related Process #{inspect(ref)}
          received DOWN message: #{inspect({ref, proc, pid, cause})}. Spawning process for re-conection
        """)

        new_pid = ReConnectProcess.start(self(), channel_ref)
        Logger.debug("Socket for channel #{channel_ref} : channel process found for re-conection: #{inspect(new_pid)}")
        Process.monitor(new_pid)

        {_commands = [], state}
    end
  end

  @impl :cowboy_websocket
  def websocket_info({:DOWN, _ref, :process, _pid, :no_channel}, state = {channel_ref, :connected, _, {_, _, _}, _}) do
    Logger.warning("Socket for channel #{channel_ref} : spawning process for re-conection")
    spawn_monitor(ReConnectProcess, :start, [self(), channel_ref])
    {_commands = [], state}
  end

  @impl :cowboy_websocket
  def websocket_info(message, state) do
    Logger.warning("Socket received socket info message: #{inspect(message)}, state: #{inspect(state)}")
    {_commands = [], state}
  end

  @impl :cowboy_websocket
  def terminate(reason, partial_req, state) do
    Logger.debug("Socket terminate with pid: #{inspect(self())}. REASON: #{inspect(reason)}. REQ: #{inspect(partial_req)}, STATE: #{inspect(state)}")

    CustomTelemetry.execute_custom_event([:adf, :socket, :disconnection], %{count: 1})

    handle_terminate(reason, partial_req, state)
  end

  #############################
  ##
  ## SUPPORT FUNCTIONS
  ##
  #############################

  defp get_relevant_request_info(req) do
    # extracts the channel key from the request query string
    get_channel_from_qs(req)
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

  defp process_subprotocol_selection(err = {:error, _}, req) do
    Logger.error("Socket unable to start. Error: #{inspect(err)}. Request: #{inspect(req)}")
    err
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

  defp handle_terminate(:normal, _req, state) do
    Logger.info("Socket with pid: #{inspect(self())} terminated with cause :normal. STATE: #{inspect(state)}")
    :ok
  end

  defp handle_terminate(:remote, _req, state) do
    Logger.info("Socket with pid: #{inspect(self())} terminated with cause :remote. STATE: #{inspect(state)}")
    :ok
  end

  defp handle_terminate(cause = {:remote, _code, _}, _req, state) do
    channel_ref = extract_ref(state)
    Logger.info("Socket with pid: #{inspect(self())}, for ref #{inspect(channel_ref)} terminated. CAUSE: #{inspect(cause)}")
    :ok
  end

  defp handle_terminate(:stop, _req, state) do
    channel_ref = extract_ref(state)
    Logger.info("Socket with pid: #{inspect(self())}, for ref #{inspect(channel_ref)} terminated with :stop. STATE: #{inspect(state)}")
    :ok
  end

  defp handle_terminate(:timeout, _req, state) do
    channel_ref = extract_ref(state)
    Logger.info("Socket with pid: #{inspect(self())}, for ref #{inspect(channel_ref)} terminated with :timeout. STATE: #{inspect(state)}")
    :ok
  end

  defp handle_terminate({:error, :closed}, _req, state) do
    channel_ref = extract_ref(state)
    Logger.warning("Socket with pid: #{inspect(self())}, for ref #{inspect(channel_ref)} was closed without receiving closing frame first")
    :ok
  end

  # handle other possible termination reasons:
  # {:crash, Class, Reason}
  # {:error, :badencoding | :badframe | :closed | Reason}
  defp handle_terminate(reason, _req, state) do
    Logger.info("Socket with pid: #{inspect(self())}, terminated with reason: #{inspect(reason)}. STATE: #{inspect(state)}")
    :ok
  end

  defp extract_ref(state) when is_tuple(state) do
    elem(state, 0)
  end
  defp extract_ref(state), do: state

  @compile {:inline, auth_ok_frame: 1}
  defp auth_ok_frame(encoder) do
    encoder.simple_frame("AuthOk")
    rescue
      _e -> {:close, @invalid_secret_code, "Invalid token for channel"}
  end

  defp ws_opts do
    timeout = get_param(:socket_idle_timeout, 90_000)
    %{
      idle_timeout: timeout,
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
