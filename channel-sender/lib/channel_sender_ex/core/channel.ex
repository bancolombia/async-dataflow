defmodule ChannelSenderEx.Core.Channel do
  @moduledoc """
  Main abstraction for modeling and active or temporarily idle async communication channel with an user.
  """
  use GenStateMachine, callback_mode: [:state_functions, :state_enter]
  require Logger
  alias ChannelSenderEx.Core.BoundedMap
  alias ChannelSenderEx.Core.ChannelIDGenerator
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.RulesProvider
  import ChannelSenderEx.Core.Retry.ExponentialBackoff, only: [exp_back_off: 4]

  @on_connected_channel_reply_timeout 2000

  @type delivery_ref() :: {pid(), reference()}
  @type output_message() :: {delivery_ref(), ProtocolMessage.t()}
  @type pending_ack() :: BoundedMap.t()
  @type pending_sending() :: BoundedMap.t()

  defmodule Data do
    @moduledoc """
    Data module stores the information for the server data
    """
    @type t() :: %ChannelSenderEx.Core.Channel.Data{
            channel: String.t(),
            application: String.t(),
            socket: {pid(), reference()},
            pending_ack: ChannelSenderEx.Core.Channel.pending_ack(),
            pending_sending: ChannelSenderEx.Core.Channel.pending_sending(),
            stop_cause: atom(),
            socket_stop_cause: atom(),
            user_ref: String.t()
          }

    defstruct channel: "",
              application: "",
              socket: nil,
              pending_ack: BoundedMap.new(),
              pending_sending: BoundedMap.new(),
              stop_cause: nil,
              socket_stop_cause: nil,
              user_ref: ""

    def new(channel, application, user_ref) do
      %Data{
        channel: channel,
        application: application,
        socket: nil,
        pending_ack: BoundedMap.new(),
        pending_sending: BoundedMap.new(),
        stop_cause: nil,
        socket_stop_cause: nil,
        user_ref: user_ref
      }
    end

  end

  @doc """
  operation to notify this server that the socket is connected
  """
  def socket_connected(server, socket_pid, timeout \\ @on_connected_channel_reply_timeout) do
    GenStateMachine.call(server, {:socket_connected, socket_pid}, timeout)
  end

  @doc """
  operation to notify this server the reason why the socket was disconnected
  """
  def socket_disconnect_reason(server, reason, timeout \\ @on_connected_channel_reply_timeout) do
    GenStateMachine.call(server, {:socket_disconnected_reason, reason}, timeout)
  end

  @doc """
  get information about this channel
  """
  def info(server, timeout \\ @on_connected_channel_reply_timeout) do
    GenStateMachine.call(server, :info, timeout)
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
  @type deliver_response :: :accepted_waiting | :accepted_connected
  @spec deliver_message(:gen_statem.server_ref(), ProtocolMessage.t()) :: deliver_response()
  def deliver_message(server, message) do
    GenStateMachine.call(server, {:deliver_message, message},
      get_param(:accept_channel_reply_timeout, 1_000)
    )
  end

  @spec start_link(any()) :: :gen_statem.start_ret()
  @doc """
  Starts the state machine.
  """
  def start_link(args = {_channel, _application, _user_ref}, opts \\ []) do
    GenStateMachine.start_link(__MODULE__, args, opts)
  end

  @impl GenStateMachine
  @doc false
  def init({channel, application, user_ref}) do
    data = Data.new(channel, application, user_ref)
    Process.flag(:trap_exit, true)
    {:ok, :waiting, data}
  end

  ############################################
  ###           WAITING STATE             ####
  ### waiting state callbacks definitions ####
  def waiting(:enter, _old_state, data) do
    # time to wait for the socket to be open (or re-opened) and authenticated
    waiting_timeout = round(estimate_process_wait_time(data) * 1000)
    case waiting_timeout do
      0 ->
        Logger.info("Channel #{data.channel} will not remain in waiting state due calculated wait time is 0. Stopping now.")
        {:stop, :normal, data}
      _ ->
        Logger.info("Channel #{data.channel} entering waiting state. Expecting a socket connection/authentication. max wait time: #{waiting_timeout} ms")
        new_data = %{data | socket_stop_cause: nil}
        {:keep_state, new_data, [{:state_timeout, waiting_timeout, :waiting_timeout}]}
    end
  end

  def waiting({:call, from}, :info, data) do
    actions = [
      _reply = {:reply, from, {:waiting, data}}
    ]
    {:keep_state_and_data, actions}
  end

  ## stop the process with a timeout cause if the socket is not
  ## authenticated in the given time
  def waiting(:state_timeout, :waiting_timeout, data) do
    Logger.warning("Channel #{data.channel} timed-out on waiting state for a socket connection and/or authentication")
    {:stop, :normal, %{data | stop_cause: :waiting_timeout}}
  end

  def waiting({:call, from}, {:socket_connected, socket_pid}, data) do
    Logger.debug("Channel #{data.channel} received socket connected notification. Socket pid: #{inspect(socket_pid)}")
    socket_ref = Process.monitor(socket_pid)
    new_data = %{data | socket: {socket_pid, socket_ref}, socket_stop_cause: nil}

    actions = [
      _reply = {:reply, from, :ok}
    ]
    Logger.debug("Channel #{data.channel} authenticated. Leaving waiting state.")
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
    Logger.debug("Channel #{data.channel} received a message while waiting for authentication")
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
    Logger.debug("Channel #{data.channel} stopping. Cause: :name_conflict")
    send(new_pid, {:twins_last_letter, data})
    {:stop, :normal, %{data | stop_cause: :name_conflict}}
  end

  def waiting(
        :info,
        {:twins_last_letter, %{pending_ack: pending_ack, pending_sending: pending_sending}},
        data
      ) do
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
    refresh_timeout = calculate_refresh_token_timeout()
    Logger.info("Channel #{data.channel} entering connected state")
    {:keep_state_and_data, [{:state_timeout, refresh_timeout, :refresh_token_timeout}]}
  end

  def connected({:call, from}, :info, data) do
    actions = [
      _reply = {:reply, from, {:connected, data}}
    ]
    {:keep_state_and_data, actions}
  end

  # this method will be called when the socket is disconnected
  # to inform this process about the disconnection reason
  # this will be later used to define if this process will go back to the waiting state
  # or if it will stop with a specific cause
  def connected({:call, from}, {:socket_disconnected_reason, reason}, data) do
    new_data = %{data | socket_stop_cause: reason}
    actions = [
      _reply = {:reply, from, :ok}
    ]
    {:keep_state, new_data, actions}
  end

  def connected(:state_timeout, :refresh_token_timeout, data) do
    refresh_timeout = calculate_refresh_token_timeout()
    message = new_token_message(data)

    {:deliver_msg, {_, ref}, _} = output = send_message(data, message)

    actions = [
      _redelivery_timeout =
        {{:timeout, {:redelivery, ref}}, get_param(:initial_redelivery_time, 900), 0},
      _refresh_timeout = {:state_timeout, refresh_timeout, :refresh_token_timeout}
    ]

    {msg_id, _, _, _, _} = message
    Logger.debug("Channel #{data.channel} sending message [:n_token] ref: #{msg_id}")
    {:keep_state,
      save_pending_ack(data, output), # new data
      actions}
  end

  ## Handle the case when a message delivery is requested.
  #@spec connected(call(), {:deliver_message, ProtocolMessage.t()}, Data.t()) :: state_return()
  def connected({:call, from}, {:deliver_message, message}, data) do

    {msg_id, _, _, _, _} = message
    Logger.debug("Channel #{data.channel} sending message [user] ref: #{msg_id}")

    # will send message to the socket process
    {:deliver_msg, {_, ref}, _} = output = send_message(data, message)

    # Prepares the actions to be executed when method returns
    # 1. reply to the caller
    # 2. schedule a timer to retry the message delivery if not acknowledged in the expected time frame
    actions = [
      _reply = {:reply, from, :accepted_connected},
      _timeout = {{:timeout, {:redelivery, ref}}, get_param(:initial_redelivery_time, 900), 0}
    ]

    new_data =
      data
      |> save_pending_ack(output) # save the message in the pending_ack map within the data
      |> clear_pending_send(message) # deletes the message from the pending_sending map

    {:keep_state, new_data, actions}
  end

  ## Handle the case when a message is acknowledged by the client.
   def connected(:info, {:ack, message_ref, message_id}, data) do
    {_, new_data} = retrieve_pending_ack(data, message_ref)

    actions = [
      _cancel_timer = {{:timeout, {:redelivery, message_ref}}, :cancel} # cancel the redelivery timer
    ]
    Logger.debug("Channel #{data.channel} recv ack msg #{message_id}")
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
        Logger.warning("Channel #{data.channel} reached max retries for message #{inspect(message_id)}")
        {:keep_state, new_data}

      _ ->
        output = send(socket_pid, create_output_message(message, ref))

        # reschedule the timer to keep retrying to deliver the message
        next_delay = round(exp_back_off(get_param(:initial_redelivery_time, 900), 3_000, retries, 0.2))
        Logger.debug("Channel #{data.channel} redelivering message in #{next_delay} ms (retry #{retries})")
        actions = [
          _timeout =
            {{:timeout, {:redelivery, ref}}, next_delay, retries + 1}
        ]

        {:keep_state, save_pending_ack(new_data, output), actions}
      end
  end

  def connected({:call, from}, {:socket_connected, socket_pid}, data = %{socket: {old_socket_pid, old_socket_ref}}) do
    Process.demonitor(old_socket_ref)
    send(old_socket_pid, :terminate_socket)
    socket_ref = Process.monitor(socket_pid)
    new_data = %{data | socket: {socket_pid, socket_ref}, socket_stop_cause: nil}

    actions = [
      _reply = {:reply, from, :ok}
    ]
    Logger.debug("Channel #{data.channel} overwritting socket pid.")
    {:keep_state, new_data, actions}
  end

  ## Handle info notification when socket process terminates. This method is called because the socket is monitored.
  ## via Process.monitor(socket_pid) in the waited/connected state.
  def connected(:info, {:DOWN, _ref, :process, _object, _reason}, data) do
    new_data = %{data | socket: nil}
    Logger.warning("Channel #{data.channel} detected socket close/disconnection. Will enter :waiting state")
    {:next_state, :waiting, new_data, []}
  end

  # test this scenario and register a callback to receive twins_last_letter in connected state
  def connected(
        :info,
        {:EXIT, _, {:name_conflict, {c_ref, _}, _, new_pid}},
        data = %{channel: c_ref}
      ) do
    Logger.warning("Channel #{data.channel} stopping")
    send(new_pid, {:twins_last_letter, data})
    {:stop, :normal, %{data | stop_cause: :name_conflict}}
  end

  # capture shutdown signal
  def connected(:info, {:EXIT, from_pid, :shutdown}, data) do
    source_process = Process.info(from_pid)
    Logger.warning("Channel #{inspect(data)} received shutdown signal: #{inspect(source_process)}")
    :keep_state_and_data
  end

  @impl true
  def terminate(reason, state, data) do
    level = if reason == :normal, do: :info, else: :warning
    Logger.log(level, "Channel #{data.channel} terminating, from state #{inspect(state)} and reason #{inspect(reason)}")
    :ok
  end

  defp new_token_message(_data = %{application: app, channel: channel, user_ref: user}) do
    new_token = ChannelIDGenerator.generate_token(channel, app, user)
    ProtocolMessage.of(UUID.uuid4(:hex), ":n_token", new_token)
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
    Logger.debug("Channel #{data.channel} saving pending ack #{msg_id}")
    %{data | pending_ack: BoundedMap.put(pending_ack, ref, message, get_param(:max_unacknowledged_queue, 100))}
  end

  @spec retrieve_pending_ack(Data.t(), reference()) :: {ProtocolMessage.t(), Data.t()}
  @compile {:inline, retrieve_pending_ack: 2}
  defp retrieve_pending_ack(data = %{pending_ack: pending_ack}, ref) do
    case BoundedMap.pop(pending_ack, ref) do
      {:noop, _} ->
        Logger.warning("Channel #{data.channel} received ack for unknown message ref #{inspect(ref)}")
        {:noop, data}
      {message, new_pending_ack} ->
        {message, %{data | pending_ack: new_pending_ack}}
    end
  end

  @spec save_pending_send(Data.t(), ProtocolMessage.t()) :: Data.t()
  @compile {:inline, save_pending_send: 2}
  defp save_pending_send(data = %{pending_sending: pending_sending}, message) do
    {msg_id, _, _, _, _} = message
    Logger.debug("Channel #{data.channel} saving pending msg #{msg_id}")
    %{
      data
      | pending_sending: BoundedMap.put(pending_sending, msg_id, message, get_param(:max_pending_queue, 100))
    }
  end

  defp clear_pending_send(data = %{pending_sending: pending}, message) do
    case BoundedMap.size(pending) do
      0 -> data
      _ ->
        {message_id, _, _, _, _} = message
        Logger.debug("Channel #{data.channel} clearing pending msg #{message_id}")
        %{data | pending_sending: BoundedMap.delete(pending, message_id)}
    end
  end

  @compile {:inline, create_output_message: 1}
  defp create_output_message(message, ref \\ make_ref()) do
    {:deliver_msg, {self(), ref}, message}
  end

  @spec calculate_refresh_token_timeout() :: integer()
  @compile {:inline, calculate_refresh_token_timeout: 0}
  defp calculate_refresh_token_timeout do
    token_validity = get_param(:max_age, 900)
    tolerance = get_param(:min_disconnection_tolerance, 50)
    min_timeout = token_validity / 2
    round(max(min_timeout, token_validity - tolerance) * 1000)
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
      {:remote, 1000, _} -> true
      _ -> false
    end
  end

  defp get_param(param, def) do
    RulesProvider.get(param)
  rescue
    _e -> def
  end
  # 1. Build init
  # 2. Build start_link with distributed capabilities ? or configurable registry
  # 3. Draf Main states

  # {from = {pid, ref}, message = [message_id, _, _, _]}
end
