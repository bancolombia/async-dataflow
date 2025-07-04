defmodule ChannelSenderEx.Transport.Socket do
  @moduledoc """
  Implements real time socket communications with cowboy
  """
  @behaviour :cowboy_websocket

  require Logger
  require OpenTelemetry.Tracer, as: Tracer

  alias ChannelSenderEx.Core.ChannelSupervisor
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
    init_result =
      get_relevant_request_info(req)
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
  def websocket_init(state = {channel, status, encoder, span}) do
    Tracer.set_current_span(span)

    Logger.debug(fn ->
      "Socket init with pid: #{inspect(self())} starting... #{inspect(state)}"
    end)

    {_commands = [], {channel, status, encoder}}
  end

  @impl :cowboy_websocket
  def websocket_handle({:text, "Auth::" <> secret}, {channel, :pre_auth, encoder}) do
    Logger.debug(fn -> "Socket #{inspect(self())} for channel #{channel} received auth" end)

    case ChannelAuthenticator.authorize_channel(channel, secret) do
      {:ok, application, user_ref} ->
        ensure_channel_exists_and_notify_socket(channel, application, user_ref, encoder)

      :unauthorized ->
        CustomTelemetry.execute_custom_event(
          [:adf, :socket, :badrequest],
          %{count: 1},
          %{request_path: "/ext/socket", status: 101, code: @invalid_secret_code}
        )

        Logger.error(fn ->
          "Socket #{inspect(self())} unable to authorize connection. Error: #{@invalid_secret_code}-invalid token for channel #{channel}"
        end)

        Tracer.add_event("Auth", %{"status" => "unauthorized", "reason" => "invalid_token"})

        {_commands = [{:close, 1001, <<@invalid_secret_code>>}], {channel, :unauthorized}}
    end
  end

  @impl :cowboy_websocket
  def websocket_handle({:text, "Ack::" <> message_id}, state) do
    Tracer.add_event("Ack", %{"msg" => message_id})

    case remove_pending(state, message_id) do
      {nil, new_state} ->
        {[], new_state}

      {{pid, ref}, new_state} ->
        send(pid, {:ack, ref, message_id})
        {[], new_state}
    end
  end

  @impl :cowboy_websocket
  def websocket_handle({:text, "Info::" <> message}, state = {channel_ref, _, _, _, _}) do
    Logger.debug(fn ->
      "Socket #{inspect(self())} for channel #{channel_ref} received info message: #{inspect(message)}"
    end)

    Tracer.add_event("Info", %{"detail" => message})

    {[], state}
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
        Tracer.add_event("Deliver", %{"msg" => message_id})
        {_commands = [encoded], new_state}

      {:error, error} ->
        Tracer.add_event("Deliver", %{
          "detail" => "Unable to encode message",
        })
        send(pid, {:non_retry_error, error, ref, message_id})
        {_commands = [], state}
    end
  end

  @impl :cowboy_websocket
  def websocket_info(:terminate_socket, state = {channel_ref, _, _, _, _}) do
    # ! check if we need to do something with the new_socket_pid
    Logger.info(fn ->
      "Socket #{inspect(self())} for channel #{channel_ref} : received terminate_socket message"
    end)

    {_commands = [{:close, 1001, <<@socket_replaced>>}], state}
  end

  @impl :cowboy_websocket
  def websocket_info({:DOWN, ref, proc, pid, cause}, state = {channel_ref, _, _, _, _}) do
    case cause do
      :normal ->
        Logger.info(fn ->
          "Socket #{inspect(self())} for channel #{channel_ref}. Related process #{inspect(ref)} down normally."
        end)

        Tracer.add_event("Down", %{
          "detail" => "DOWN message received, process down normally"
        })

        {_commands = [{:close, 1000, <<@normal_close_code>>}], state}

      _ ->
        Logger.warning("""
          Socket #{inspect(self())} for channel #{channel_ref}. Related Process #{inspect(ref)}
          received DOWN message: #{inspect({ref, proc, pid, cause})}. Spawning process for re-conection
        """)

        Tracer.add_event("Down", %{
          "detail" => "DOWN message starting re-connect process with cause: #{inspect(cause)}"
        })

        ReConnectProcess.start(self(), channel_ref, :websocket)

        {_commands = [], state}
    end
  end

  @impl :cowboy_websocket
  def websocket_info(
        {:DOWN, _ref, :process, _pid, :no_channel},
        state = {channel_ref, :connected, _, {_, _, _}, _}
      ) do
    Logger.warning(fn ->
      "Socket #{inspect(self())} for channel #{channel_ref} : spawning process for re-conection"
    end)

    Tracer.add_event("Down", %{
      "detail" => "DOWN message starting re-connect process"
    })

    ReConnectProcess.start(self(), channel_ref, :websocket)

    {_commands = [], state}
  end

  @impl :cowboy_websocket
  def websocket_info({:monitor_channel, channel_ref, new_pid}, state) do
    Logger.debug(fn ->
      "Socket #{inspect(self())} for channel #{channel_ref} : channel process found for re-conection: #{inspect(new_pid)}"
    end)

    Process.monitor(new_pid)

    {_commands = [], state}
  end

  @impl :cowboy_websocket
  def websocket_info(message, state) do
    Logger.warning(fn ->
      "Socket #{inspect(self())} received socket info message: #{inspect(message)}, state: #{inspect(state)}"
    end)

    {_commands = [], state}
  end

  @impl :cowboy_websocket
  def terminate(reason, partial_req, state) do
    Logger.debug(fn ->
      "Socket terminate with pid: #{inspect(self())}. REASON: #{inspect(reason)}. REQ: #{inspect(partial_req)}, STATE: #{inspect(state)}"
    end)

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
    rs = get_channel_from_qs(req)
    Logger.debug(fn -> "Socket #{inspect(self())} starting with parameter: #{inspect(rs)}" end)
    rs
  end

  defp process_subprotocol_selection({@channel_key, channel}, req) do
    case :cowboy_req.parse_header("sec-websocket-protocol", req) do
      :undefined ->
        span = CustomTelemetry.start_span(:socket, req, channel)

        {:cowboy_websocket, req,
         _state =
           {channel, :pre_auth,
            Application.get_env(
              :channel_sender_ex,
              :message_encoder,
              ChannelSenderEx.Transport.Encoders.JsonEncoder
            ), span}, ws_opts()}

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

        span = CustomTelemetry.start_span(:socket, req, channel)
        {:cowboy_websocket, req, _state = {channel, :pre_auth, encoder, span}, ws_opts()}
    end
  end

  defp process_subprotocol_selection(err = {:error, _}, req) do
    Logger.error(fn ->
      "Socket #{inspect(self())} unable to start. Error: #{inspect(err)}. Request: #{inspect(req)}"
    end)

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
    Logger.info(fn ->
      "Socket with pid: #{inspect(self())} terminated with cause :normal. STATE: #{inspect(state)}"
    end)

    CustomTelemetry.end_span("normal")

    :ok
  end

  defp handle_terminate(:remote, _req, state) do
    Logger.info(fn ->
      "Socket with pid: #{inspect(self())} terminated with cause :remote. STATE: #{inspect(state)}"
    end)

    CustomTelemetry.end_span("remote")

    :ok
  end

  defp handle_terminate(cause = {:remote, code, _}, _req, state) do
    channel_ref = extract_ref(state)

    Logger.info(fn ->
      "Socket with pid: #{inspect(self())}, for ref #{inspect(channel_ref)} terminated. CAUSE: #{inspect(cause)}"
    end)

    CustomTelemetry.end_span("#{code}")

    :ok
  end

  defp handle_terminate(:stop, _req, state) do
    channel_ref = extract_ref(state)

    Logger.info(fn ->
      "Socket with pid: #{inspect(self())}, for ref #{inspect(channel_ref)} terminated with :stop. STATE: #{inspect(state)}"
    end)

    CustomTelemetry.end_span("stop")

    :ok
  end

  defp handle_terminate(:timeout, _req, state) do
    channel_ref = extract_ref(state)

    Logger.info(fn ->
      "Socket with pid: #{inspect(self())}, for ref #{inspect(channel_ref)} terminated with :timeout. STATE: #{inspect(state)}"
    end)

    CustomTelemetry.end_span("timeout")

    :ok
  end

  defp handle_terminate({:error, :closed}, _req, state) do
    channel_ref = extract_ref(state)

    Logger.warning(fn ->
      "Socket with pid: #{inspect(self())}, for ref #{inspect(channel_ref)} was closed without receiving closing frame first"
    end)

    CustomTelemetry.end_span("closed no frame")

    :ok
  end

  # handle other possible termination reasons:
  # {:crash, Class, Reason}
  # {:error, :badencoding | :badframe | :closed | Reason}
  defp handle_terminate(reason, _req, state) do
    Logger.info(fn ->
      "Socket with pid: #{inspect(self())}, terminated with reason: #{inspect(reason)}. STATE: #{inspect(state)}"
    end)

    Tracer.set_status(OpenTelemetry.status(:error, "#{inspect(reason)}"))
    CustomTelemetry.end_span("other")

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
    e ->
      Logger.error(fn ->
        "Socket #{inspect(self())} unable to send auth ok frame: #{inspect(e)}"
      end)

      {:close, @invalid_secret_code, "Invalid token for channel"}
  end

  defp ws_opts do
    timeout = get_param(:socket_idle_timeout, 90_000)

    %{
      idle_timeout: timeout,
      #      active_n: 5,
      #      compress: false,
      #      deflate_opts: %{},
      max_frame_size: 4096,
      # Disable in pdn
      # validate_utf8: true,
      # Usefull to save space avoiding to save all request info
      req_filter: fn %{qs: qs, peer: peer} -> {qs, peer} end
    }
  end

  defp ensure_channel_exists_and_notify_socket(channel, application, user_ref, encoder) do
    args = {channel, application, user_ref, []}

    case ChannelSupervisor.start_channel_if_not_exists(args) do
      {:ok, pid} ->
        monitor_ref = notify_connected(pid, :websocket)

        CustomTelemetry.execute_custom_event([:adf, :socket, :connection], %{count: 1})

        state = {channel, :connected, encoder, {application, user_ref, monitor_ref}, %{}}
        Tracer.add_event("Auth", %{"status" => "success"})
        {_commands = [auth_ok_frame(encoder)], state}

      {:error, reason} ->
        Logger.error(fn ->
          "Channel #{channel} not exists and unable to start. Reason: #{inspect(reason)}"
        end)

        Tracer.add_event("Auth", %{"status" => "unauthorized", "reason" => "not_exists"})

        {_commands = [{:close, 1001, <<@invalid_channel_code>>}], {channel, :unauthorized}}
    end
  end
end
