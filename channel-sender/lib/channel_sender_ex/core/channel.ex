defmodule ChannelSenderEx.Core.Channel do
  # credo:disable-for-this-file Credo.Check.Readability.PreferImplicitTry

  @moduledoc """
  Main abstraction for modeling and active or temporarily idle async communication channel with an user.
  """
  use GenStateMachine, callback_mode: [:state_functions, :state_enter], restart: :transient
  require Logger
  alias ChannelSenderEx.Core.BoundedMap
  alias ChannelSenderEx.Core.ChannelIDGenerator
  alias ChannelSenderEx.Core.ChannelSupervisor
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.RulesProvider
  alias ChannelSenderEx.Utils.CustomTelemetry
  import ChannelSenderEx.Core.Retry.ExponentialBackoff, only: [exp_back_off: 4]

  @on_connected_channel_reply_timeout 2000
  # 40% of token life remaining will signal a renovation action
  @token_remaining_life_to_renovate 40

  @type delivery_ref() :: {pid(), reference()}
  @type output_message() :: {delivery_ref(), ProtocolMessage.t()}
  @type pending_ack() :: BoundedMap.t()
  @type pending_sending() :: BoundedMap.t()
  @type deliver_response :: :accepted_waiting | :accepted_connected
  @type kind() :: :websocket | :sse | :longpoll

  defmodule Data do
    @moduledoc """
    Data module stores the information for the server data
    """
    @type t() :: %ChannelSenderEx.Core.Channel.Data{
            channel: String.t(),
            application: String.t(),
            socket: {pid(), reference()},
            socket_kind: ChannelSenderEx.Core.Channel.kind(),
            pending_ack: ChannelSenderEx.Core.Channel.pending_ack(),
            pending_sending: ChannelSenderEx.Core.Channel.pending_sending(),
            stop_cause: atom(),
            socket_stop_cause: atom(),
            user_ref: String.t(),
            token_expiry: integer(),
            connect_time: integer(),
            meta: String.t()
          }

    defstruct channel: "",
              application: "",
              socket: nil,
              socket_kind: nil,
              pending_ack: BoundedMap.new(),
              pending_sending: BoundedMap.new(),
              stop_cause: nil,
              socket_stop_cause: nil,
              user_ref: "",
              token_expiry: 0,
              connect_time: 0,
              meta: nil

    def new(channel, application, user_ref, meta) do
      %Data{
        channel: channel,
        application: application,
        socket: nil,
        socket_kind: nil,
        pending_ack: BoundedMap.new(),
        pending_sending: BoundedMap.new(),
        stop_cause: nil,
        socket_stop_cause: nil,
        user_ref: user_ref,
        token_expiry: 0,
        connect_time: :erlang.system_time(:millisecond),
        meta: meta
      }
    end
  end

  @spec alive?(atom() | pid() | {atom(), any()} | {:via, atom(), any()}) :: boolean()
  def alive?(server) do
    safe_alive?(server, self())
  end

  @doc """
  operation to notify this server that the socket is connected
  """
  def socket_connected(server, socket_pid, timeout \\ @on_connected_channel_reply_timeout) do
    GenStateMachine.call(server, {:socket_connected, socket_pid, :websocket}, timeout)
  end

  @doc """
  operation to notify this server that the sse process is connected
  """
  def sse_connected(server, sse_pid, timeout \\ @on_connected_channel_reply_timeout) do
    GenStateMachine.call(server, {:socket_connected, sse_pid, :sse}, timeout)
  end

  @doc """
  operation to notify this server that the longpoll process is connected
  """
  def longpoll_connected(server, poll_pid, timeout \\ @on_connected_channel_reply_timeout) do
    GenStateMachine.call(server, {:socket_connected, poll_pid, :longpoll}, timeout)
  end

  @doc """
  operation to mark a message as acknowledged
  """
  def notify_ack(server, ref, message_id) do
    send(server, {:ack, ref, message_id})
  end

  @doc """
  operation to request a message delivery
  """
  @spec deliver_message(:gen_statem.server_ref(), ProtocolMessage.t()) :: deliver_response()
  def deliver_message(server, message) do
    GenStateMachine.call(
      server,
      {:deliver_message, message},
      get_param(:accept_channel_reply_timeout, 1_000)
    )
  end

  def stop(server) do
    GenStateMachine.call(server, :stop)
  end

  @spec start_link(any()) :: :gen_statem.start_ret()
  @doc """
  Starts the state machine.
  """
  def start_link(args = {_channel, _application, _user_ref, _meta}, opts \\ []) do
    GenStateMachine.start_link(__MODULE__, args, opts)
  end

  @impl GenStateMachine
  @doc false
  def init({channel, application, user_ref, meta}) do
    ChannelSupervisor.register_pid(channel, self())

    data =
      Data.new(channel, application, user_ref, meta)
      |> Map.put(:token_expiry, calculate_token_expiration_time())

    Process.flag(:trap_exit, true)

    {:ok, :waiting, data}
  end

  ############################################
  ###           WAITING STATE             ####
  ### waiting state callbacks definitions ####

  defp check_process(_waiting_tomeout = 0, %{channel: channel}) do
    Logger.info(fn ->
      "Channel #{channel} will not remain in waiting state due calculated wait time is 0. Stopping now."
    end)

    :timeout
  end

  defp check_process(
         _waiting_tomeout,
         _data = %{channel: channel, application: application, user_ref: user_ref, meta: meta}
       ) do
    current_pid = self()

    case ChannelSupervisor.register_channel_if_not_exists({channel, application, user_ref, meta}) do
      {:ok, ^current_pid} ->
        Logger.debug(fn ->
          "Channel #{channel} is registered with self() pid #{inspect(current_pid)}"
        end)

        :existing

      {:ok, pid} ->
        Logger.debug(fn ->
          "Channel #{channel} re-registration or exists with another pid #{inspect(pid)} stoping self #{inspect(self())}"
        end)

        :registered
    end
  end

  def waiting(:enter, _old_state, data) do
    # time to wait for the socket to be open (or re-opened) and authenticated
    waiting_timeout = round(estimate_process_wait_time(data) * 1000)

    case check_process(waiting_timeout, data) do
      :timeout ->
        CustomTelemetry.execute_custom_event([:adf, :channel, :deleted], %{count: 1})
        {:stop, :normal, data}

      :registered ->
        {:stop, :normal, data}

      _ ->
        Logger.info(
          "Channel #{data.channel} entering waiting state. Expecting a socket/sse/longpoll connection/authentication. max wait time: #{waiting_timeout} ms"
        )

        new_data = %{data | socket_stop_cause: nil}
        {:keep_state, new_data, [{:state_timeout, waiting_timeout, :waiting_timeout}]}
    end
  end

  def waiting({:call, from}, :alive?, _data) do
    {:keep_state_and_data, [{:reply, from, true}]}
  end

  def waiting({:call, from}, :stop, data) do
    actions = [
      _reply = {:reply, from, :ok}
    ]

    Logger.info(fn -> "Channel #{data.channel} stopping, reason: :explicit_close" end)
    {:next_state, :closed, %{data | stop_cause: :explicit_close}, actions}
  end

  ## stop the process with a timeout cause if the socket is not
  ## authenticated in the given time
  def waiting(:state_timeout, :waiting_timeout, data) do
    Logger.warning(
      "Channel #{data.channel} timed-out on waiting state for a socket connection and/or authentication"
    )

    {:stop, :normal, %{data | stop_cause: :waiting_timeout}}
  end

  def waiting({:call, from}, {:socket_connected, socket_pid, kind}, data) do
    Logger.debug(
      "Channel #{data.channel} received #{kind} connected notification. Pid: #{inspect(socket_pid)}"
    )

    socket_ref = Process.monitor(socket_pid)

    new_data = %{
      data
      | socket: {socket_pid, socket_ref},
        socket_kind: kind,
        socket_stop_cause: nil,
        connect_time: :erlang.system_time(:millisecond)
    }

    actions = [
      _reply = {:reply, from, :ok}
    ]

    Logger.debug(fn -> "Channel #{data.channel} authenticated. Leaving waiting state." end)
    {:next_state, :connected, new_data, actions}
  end

  ## Handle the case when a message delivery is requested in the waiting state. In this case
  ## the message is saved in the pending_sending map.
  def waiting(
        {:call, from},
        {:deliver_message, message},
        data
      ) do
    actions = [
      _reply = {:reply, from, :accepted_waiting},
      _postpone = :postpone
    ]

    Logger.debug(fn ->
      "Channel #{data.channel} received a message while waiting for authentication"
    end)

    new_data = save_pending_send(data, message)
    {:keep_state, new_data, actions}
  end

  def waiting({:timeout, {:redelivery, _ref}}, _, _data) do
    {:keep_state_and_data, :postpone}
  end

  def waiting({:call, _from}, _event, _data) do
    :keep_state_and_data
  end

  def waiting(
        :info,
        {:EXIT, _, {:name_conflict, {c_ref, _}, _, new_pid}},
        data = %{channel: c_ref}
      ) do
    Logger.warning(
      "Channel #{data.channel}, stopping process #{inspect(self())} in status :waiting due to :name_conflict, and starting new process #{inspect(new_pid)}"
    )

    send(new_pid, {:twins_last_letter, data})
    {:stop, :normal, %{data | stop_cause: :name_conflict}}
  end

  def waiting(
        :info,
        {:twins_last_letter, %{pending_ack: pending_ack, pending_sending: pending_sending}},
        data
      ) do
    Logger.warning(fn -> "Channel #{data.channel}, received twins_last_letter" end)

    new_data = %{
      data
      | pending_ack: BoundedMap.merge(pending_ack, data.pending_ack),
        pending_sending: BoundedMap.merge(pending_sending, data.pending_sending)
    }

    {:keep_state, new_data}
  end

  def waiting(:info, _event, _data) do
    :keep_state_and_data
  end

  #############################################
  ###           CONNECTED STATE            ####
  #############################################

  @type call() :: {:call, GenServer.from()}
  @type state_return() :: :gen_statem.event_handler_result(Data.t())

  def connected(:enter, _old_state, data) do
    refresh_timeout = calculate_refresh_token_timeout(data.socket_kind)

    Logger.info(fn ->
      "Channel #{data.channel} entering connected state with refresh timeout: #{inspect(refresh_timeout / 1000)} seconds"
    end)

    {:keep_state_and_data, [{:state_timeout, refresh_timeout, :refresh_token_timeout}]}
  end

  def connected({:call, from}, :alive?, _data) do
    {:keep_state_and_data, [{:reply, from, true}]}
  end

  def connected(
        {:call, from},
        {:socket_connected, socket_pid, _},
        data = %{socket: {old_socket_pid, _old_socket_ref}}
      )
      when socket_pid == old_socket_pid do
    # socket already connected
    actions = [
      _reply = {:reply, from, :ok}
    ]

    Logger.debug(fn -> "Channel #{data.channel} #{data.socket_kind} pid already connected." end)
    {:keep_state_and_data, actions}
  end

  def connected(
        {:call, from},
        {:socket_connected, socket_pid, _},
        data = %{socket: {old_socket_pid, old_socket_ref}}
      ) do
    Process.demonitor(old_socket_ref)
    send(old_socket_pid, :terminate_socket)
    socket_ref = Process.monitor(socket_pid)

    new_data = %{
      data
      | socket: {socket_pid, socket_ref},
        socket_stop_cause: nil,
        connect_time: :erlang.system_time(:millisecond)
    }

    actions = [
      _reply = {:reply, from, :ok}
    ]

    Logger.debug(fn ->
      "Channel #{data.channel} overwritting #{data.socket_kind} pid from #{inspect(old_socket_pid)} to #{inspect(socket_pid)}"
    end)

    {:keep_state, new_data, actions}
  end

  def connected(:state_timeout, :refresh_token_timeout, data) do
    if calculate_token_remaining_life(data.token_expiry) < @token_remaining_life_to_renovate do
      message = new_token_message(data)
      {msg_id, _, _, _, _} = message

      {:deliver_msg, {_, ref}, _} = output = send_message(data, message)

      actions = [
        _redelivery_timeout =
          {{:timeout, {:redelivery, ref}}, get_param(:initial_redelivery_time, 900), 0},
        _refresh_timeout =
          {:state_timeout, calculate_refresh_token_timeout(data.socket_kind),
           :refresh_token_timeout}
      ]

      Logger.debug(fn -> "Channel #{data.channel} sending message [:n_token] ref: #{msg_id}" end)

      {
        :keep_state,
        # new data
        save_pending_ack(%{data | token_expiry: calculate_token_expiration_time()}, output),
        actions
      }
    else
      Logger.debug(
        "Channel #{data.channel} token holds > #{@token_remaining_life_to_renovate}% life, not updating"
      )

      {
        :keep_state_and_data,
        [
          _refresh_timeout =
            {:state_timeout, calculate_refresh_token_timeout(data.socket_kind),
             :refresh_token_timeout}
        ]
      }
    end
  end

  ## Handle the case when a message delivery is requested.
  # @spec connected(call(), {:deliver_message, ProtocolMessage.t()}, Data.t()) :: state_return()
  def connected({:call, from}, {:deliver_message, message}, data) do
    {msg_id, _, _, _, _} = message
    Logger.debug(fn -> "Channel #{data.channel} sending message [user] ref: #{msg_id}" end)

    # will send message to the socket process
    {:deliver_msg, {_, ref}, _} = output = send_message(data, message)

    CustomTelemetry.execute_custom_event([:adf, :message, :delivered], %{count: 1})

    # Prepares the actions to be executed when method returns
    # 1. reply to the caller
    # 2. schedule a timer to retry the message delivery if not acknowledged in the expected time frame
    actions = [
      _reply = {:reply, from, :accepted_connected},
      _timeout = {{:timeout, {:redelivery, ref}}, get_param(:initial_redelivery_time, 900), 0}
    ]

    new_data =
      data
      # save the message in the pending_ack map within the data
      |> save_pending_ack(output)
      # deletes the message from the pending_sending map
      |> clear_pending_send(message)

    {:keep_state, new_data, actions}
  end

  ## Handle the case when a message is acknowledged by the client.
  def connected(:info, {:ack, message_ref, message_id}, data) do
    {_, new_data} = retrieve_pending_ack(data, message_ref)

    actions = [
      # cancel the redelivery timer
      _cancel_timer = {{:timeout, {:redelivery, message_ref}}, :cancel}
    ]

    Logger.debug(fn -> "Channel #{data.channel} recv ack msg #{message_id}" end)
    {:keep_state, new_data, actions}
  end

  ## This is basically a message re-delivery timer. It is triggered when a message is requested to be delivered.
  ## And it will continue to be executed until the message is acknowledged by the client.
  def connected({:timeout, {:redelivery, ref}}, retries, data = %{socket: {socket_pid, _}}) do
    {message, new_data} = retrieve_pending_ack(data, ref)

    max_unacknowledged_retries = get_param(:max_unacknowledged_retries, 20)

    case retries do
      r when r >= max_unacknowledged_retries ->
        {message_id, _, _, _, _} = message

        Logger.warning(
          "Channel #{data.channel} reached max retries for message #{inspect(message_id)}"
        )

        {:keep_state, new_data}

      _ ->
        output = send(socket_pid, create_output_message(message, ref))

        # reschedule the timer to keep retrying to deliver the message
        next_delay =
          round(exp_back_off(get_param(:initial_redelivery_time, 900), 3_000, retries, 0.2))

        Logger.debug(
          "Channel #{data.channel} redelivering message in #{next_delay} ms (retry #{retries})"
        )

        actions = [
          _timeout =
            {{:timeout, {:redelivery, ref}}, next_delay, retries + 1}
        ]

        {:keep_state, save_pending_ack(new_data, output), actions}
    end
  end

  ## Handle info notification when socket process terminates. This method is called because the socket is monitored.
  ## via Process.monitor(socket_pid) in the waited/connected state.
  def connected(:info, {:DOWN, _ref, :process, _object, reason}, data) do
    new_data = %{data | socket: nil, socket_stop_cause: reason}

    Logger.warning(
      "Channel #{data.channel} detected #{data.socket_kind} close/disconnection. Will enter :waiting state"
    )

    {:next_state, :waiting, new_data, []}
  end

  # test this scenario and register a callback to receive twins_last_letter in connected state
  def connected(
        :info,
        {:EXIT, _, {:name_conflict, {c_ref, _}, _, new_pid}},
        data = %{channel: c_ref}
      ) do
    Logger.warning(
      "Channel #{data.channel}, stopping process #{inspect(self())} in status :waiting due to :name_conflict, and starting new process #{inspect(new_pid)}"
    )

    send(new_pid, {:twins_last_letter, data})
    {:stop, :normal, %{data | stop_cause: :name_conflict}}
  end

  # capture shutdown signal
  def connected(:info, {:EXIT, from_pid, :shutdown}, data) do
    source_process = Process.info(from_pid)

    Logger.info(fn ->
      "Channel #{inspect(data)} received shutdown signal: #{inspect(source_process)}"
    end)

    :keep_state_and_data
  end

  # capture any other info message
  def connected(
        :info,
        info_payload,
        data
      ) do
    Logger.warning(
      "Channel #{data.channel} receceived unknown info message #{inspect(info_payload)}"
    )

    {:keep_state_and_data, :postpone}
  end

  def connected({:call, from}, :stop, data) do
    actions = [
      _reply = {:reply, from, :ok}
    ]

    Logger.debug(fn -> "Channel #{data.channel} stopping, reason: :explicit_close" end)
    {:next_state, :closed, %{data | stop_cause: :explicit_close}, actions}
  end

  defp new_token_message(_data = %{application: app, channel: channel, user_ref: user}) do
    new_token = ChannelIDGenerator.generate_token(channel, app, user)
    ProtocolMessage.of(UUID.uuid4(:hex), ":n_token", new_token)
  end

  ############################################
  ###           CLOSED STATE              ####
  ############################################

  def closed(:enter, _old_state, data) do
    Logger.debug(fn ->
      "Channel #{data.channel} enter state closed."
    end)

    {:stop, :normal, data}
  end

  @impl true
  def terminate(reason, state, data) do
    CustomTelemetry.execute_custom_event([:adf, :channel, :deleted], %{count: 1})
    level = if reason == :normal, do: :info, else: :warning

    Logger.log(
      level,
      """
      Channel #{data.channel} terminating, from state #{inspect(state)} and reason #{inspect(reason)}. Data: #{inspect(data)}
      """
    )

    :ok
  end

  #########################################
  ###      Support functions           ####
  #########################################

  @compile {:inline, send_message: 2}
  defp send_message(%{socket: {socket_pid, _}}, message) do
    # creates message to the expected format
    output = create_output_message(message)
    # sends to socket pid
    send(socket_pid, output)
  end

  @compile {:inline, save_pending_ack: 2}
  defp save_pending_ack(data = %{pending_ack: pending_ack}, {:deliver_msg, {_, ref}, message}) do
    {msg_id, _, _, _, _} = message
    Logger.debug(fn -> "Channel #{data.channel} saving pending ack #{msg_id}" end)
    # ! add a metric here to increment pending ack count
    # CustomTelemetry.execute_custom_event([:adf, :channel, :pending, :ack], %{count: 1})
    %{
      data
      | pending_ack:
          BoundedMap.put(pending_ack, ref, message, get_param(:max_unacknowledged_queue, 100))
    }
  end

  @spec retrieve_pending_ack(Data.t(), reference()) :: {ProtocolMessage.t(), Data.t()}
  @compile {:inline, retrieve_pending_ack: 2}
  defp retrieve_pending_ack(data = %{pending_ack: pending_ack}, ref) do
    case BoundedMap.pop(pending_ack, ref) do
      {:noop, _} ->
        Logger.warning(
          "Channel #{data.channel} received ack for unknown message ref #{inspect(ref)}"
        )

        {:noop, data}

      {message, new_pending_ack} ->
        # ! add a metric here to decrement pending ack count
        # CustomTelemetry.execute_custom_event([:adf, :channel, :pending, :ack], %{count: -1})
        {message, %{data | pending_ack: new_pending_ack}}
    end
  end

  @spec save_pending_send(Data.t(), ProtocolMessage.t()) :: Data.t()
  @compile {:inline, save_pending_send: 2}
  defp save_pending_send(data = %{pending_sending: pending_sending}, message) do
    {msg_id, _, _, _, _} = message
    Logger.debug(fn -> "Channel #{data.channel} saving pending msg #{msg_id}" end)
    # ! add a metric here to increment pending send count
    # CustomTelemetry.execute_custom_event([:adf, :channel, :pending, :send], %{count: 1})
    %{
      data
      | pending_sending:
          BoundedMap.put(pending_sending, msg_id, message, get_param(:max_pending_queue, 100))
    }
  end

  defp clear_pending_send(data = %{pending_sending: pending}, message) do
    case BoundedMap.size(pending) do
      0 ->
        data

      _ ->
        {message_id, _, _, _, _} = message
        Logger.debug(fn -> "Channel #{data.channel} clearing pending msg #{message_id}" end)
        # ! add a metric here to decrement pending send count
        # CustomTelemetry.execute_custom_event([:adf, :channel, :pending, :send], %{count: -1})
        %{data | pending_sending: BoundedMap.delete(pending, message_id)}
    end
  end

  @compile {:inline, create_output_message: 1}
  defp create_output_message(message, ref \\ make_ref()) do
    {:deliver_msg, {self(), ref}, message}
  end

  defp calculate_token_expiration_time do
    token_life_millis =
      get_param(:max_age, 900) * 1000 -
        get_param(:min_disconnection_tolerance, 50) * 1000

    :erlang.system_time(:millisecond) + token_life_millis
  end

  defp calculate_token_remaining_life(token_expiry) do
    current_time = :erlang.system_time(:millisecond)
    diff_seconds = (token_expiry - current_time) / 1000
    diff_seconds * 100 / get_param(:max_age, 900)
  end

  defp calculate_refresh_token_timeout(:websocket) do
    token_validity = get_param(:max_age, 900)
    min_timeout = token_validity / 6
    # 15% of the token life for websocket connections
    round(min_timeout * 1000)
  end

  defp calculate_refresh_token_timeout(_) do
    # 25 seconds for SSE and LONGPOLL connections
    25_000
  end

  defp estimate_process_wait_time(data) do
    # when is a new socket connection this will resolve false
    case socket_clean_disconnection?(data) do
      true ->
        get_param(:channel_shutdown_on_clean_close, 30)

      false ->
        # this time will also apply when socket the first time connected
        get_param(:channel_shutdown_on_disconnection, 300)
    end
  end

  defp socket_clean_disconnection?(data) do
    case data.socket_stop_cause do
      :normal -> true
      {:remote, 1000, _} -> true
      _ -> false
    end
  end

  defp get_param(param, def) do
    RulesProvider.get(param)
  rescue
    _e -> def
  end

  defp safe_alive?(pid, self_pid) when pid == self_pid do
    true
  end

  defp safe_alive?(pid, _self_pid) do
    try do
      GenServer.call(pid, :alive?)
    catch
      :exit, _ -> false
    end
  end
end
