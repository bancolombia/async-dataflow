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
            stop_cause: atom(),
            socket: {pid(), reference()},
            pending_ack: ChannelSenderEx.Core.Channel.pending_ack(),
            pending_sending: ChannelSenderEx.Core.Channel.pending_sending(),
            user_ref: String.t()
          }

    defstruct channel: "",
              application: "",
              socket: nil,
              pending_ack: BoundedMap.new(),
              pending_sending: BoundedMap.new(),
              stop_cause: nil,
              user_ref: ""

    def new(channel, application, user_ref) do
      %Data{
        channel: channel,
        application: application,
        socket: nil,
        pending_ack: BoundedMap.new(),
        pending_sending: BoundedMap.new(),
        stop_cause: nil,
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
    GenStateMachine.call(server, {:deliver_message, message}, Application.get_env(
      :channel_sender_ex,
      :accept_channel_reply_timeout
    ))
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
    # time to wait for the socket to be authenticated
    waiting_timeout = round(get_param(:max_age, 900) * 1000)
    Logger.debug("Channel #{data.channel} entering waiting state and expecting a socket connection and authentication. max wait time: #{waiting_timeout} ms")
    {:keep_state, data, [{:state_timeout, waiting_timeout, :waiting_timeout}]}
  end

  ## stop the process with a timeout cause if the socket is not
  ## authenticated in the given time
  def waiting(:state_timeout, :waiting_timeout, data) do
    Logger.warning("Channel #{data.channel} timed-out on waiting state for a socket connection and/or authentication")
    {:stop, :normal, %{data | stop_cause: :waiting_timeout}}
  end

  def waiting({:call, from}, {:socket_connected, socket_pid}, data) do
    socket_ref = Process.monitor(socket_pid)
    new_data = %{data | socket: {socket_pid, socket_ref}}

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

  ################### END######################
  ###           WAITING STATE             ####
  ############################################

  @type call() :: {:call, GenServer.from()}
  @type state_return() :: :gen_statem.event_handler_result(Data.t())

  def connected(:enter, _old_state, data) do
    refresh_timeout = calculate_refresh_token_timeout()
    Logger.debug("Channel #{data.channel} entering connected state")
    {:keep_state_and_data, [{:state_timeout, refresh_timeout, :refresh_token_timeout}]}
  end

  def connected(:state_timeout, :refresh_token_timeout, data) do
    refresh_timeout = calculate_refresh_token_timeout()
    message = new_token_message(data)

    {:deliver_msg, {_, ref}, _} = output = send_message(data, message)

    actions = [
      _redelivery_timeout =
        {{:timeout, {:redelivery, ref}}, get_param(:initial_redelivery_time, 500), 0},
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
      _timeout = {{:timeout, {:redelivery, ref}}, get_param(:initial_redelivery_time, 500), 0}
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
    output = send(socket_pid, create_output_message(message, ref))

    # reschedule the timer to keep retrying to deliver the message
    actions = [
      _timeout =
        {{:timeout, {:redelivery, ref}}, get_param(:initial_redelivery_time, 500), retries + 1}
    ]

    {:keep_state, save_pending_ack(new_data, output), actions}
  end

  ## Handle the case when the socket is disconnected. This method is called because the socket is monitored.
  ## via Process.monitor(socket_pid) in the waited/connected state.
  def connected(:info, {:DOWN, _ref, :process, _object, _reason}, data) do
    new_data = %{data | socket: nil}
    actions = []

    Logger.warning("Channel #{data.channel} detected socket disconnection, entering :waiting state")

    # returns to the waiting state
    {:next_state, :waiting, new_data, actions}
  end

  # def connected(:info, _m = {:DOWN, _ref, :process, _object, _reason}, _data) do
  #   Logger.warning(":DOWN message received")
  #   :keep_state_and_data
  # end

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

  @compile {:inline, send_message: 2}
  defp send_message(%{socket: {socket_pid, _}}, message) do
    # creates message to the expected format
    output = create_output_message(message)
    # sends to socket pid
    send(socket_pid, output)
  end

  #@spec save_pending_ack(Data.t(), output_message()) :: Data.t()
  @compile {:inline, save_pending_ack: 2}
  defp save_pending_ack(data = %{pending_ack: pending_ack}, {:deliver_msg, {_, ref}, message}) do
    {msg_id, _, _, _, _} = message
    Logger.debug("Channel #{data.channel} saving pending ack #{msg_id}")
    %{data | pending_ack: BoundedMap.put(pending_ack, ref, message)}
  end

  @spec retrieve_pending_ack(Data.t(), reference()) :: {ProtocolMessage.t(), Data.t()}
  @compile {:inline, retrieve_pending_ack: 2}
  defp retrieve_pending_ack(data = %{pending_ack: pending_ack}, ref) do
    {message, new_pending_ack} = BoundedMap.pop(pending_ack, ref)
    {message, %{data | pending_ack: new_pending_ack}}
  end

  @spec save_pending_send(Data.t(), ProtocolMessage.t()) :: Data.t()
  @compile {:inline, save_pending_send: 2}
  defp save_pending_send(data = %{pending_sending: pending_sending}, message) do
    {msg_id, _, _, _, _} = message
    Logger.debug("Channel #{data.channel} saving pending msg #{msg_id}")
    %{
      data
      | pending_sending: BoundedMap.put(pending_sending, msg_id, message)
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
