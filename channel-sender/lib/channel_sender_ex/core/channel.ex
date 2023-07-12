defmodule ChannelSenderEx.Core.Channel do
  @moduledoc """
  Main abstraction for modeling and active or temporarily idle async communication channel with an user.
  """
  use GenStateMachine, callback_mode: [:state_functions, :state_enter]
  require Logger
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.RulesProvider

  # Max allowed time in waiting before terminate the channel
  #  @waiting_timeout Application.get_env(:channel_sender_ex, :channel_waiting_timeout, 30)
  #  @message_time_to_live Application.get_env(:channel_sender_ex, :message_time_to_live, 8000)
  @token_max_age :max_age
  @min_disconnection_tolerance :min_disconnection_tolerance
  @on_connected_channel_reply_timeout Application.get_env(
                                        :channel_sender_ex,
                                        :on_connected_channel_reply_timeout,
                                        2000
                                      )
  @accept_channel_reply_timeout Application.get_env(
                                  :channel_sender_ex,
                                  :accept_channel_reply_timeout,
                                  1000
                                )

  @type delivery_ref() :: {pid(), reference()}
  @type output_message() :: {delivery_ref(), ProtocolMessage.t()}
  @type pending_ack() :: %{optional(reference()) => ProtocolMessage.t()}
  @type pending_sending() :: %{optional(String.t()) => ProtocolMessage.t()}

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
            pending_sending: ChannelSenderEx.Core.Channel.pending_ack(),
            user_ref: String.t()
          }

    defstruct channel: "",
              application: "",
              socket: nil,
              pending_ack: %{},
              pending_sending: %{},
              stop_cause: nil,
              user_ref: ""
  end

  def socket_connected(server, socket_pid, timeout \\ @on_connected_channel_reply_timeout) do
    GenStateMachine.call(server, {:socket_connected, socket_pid}, timeout)
  end

  def notify_ack(server, ref, message_id) do
    send(server, {:ack, ref, message_id})
  end

  @type deliver_response :: :accepted_waiting | :accepted_connected
  @spec deliver_message(:gen_statem.server_ref(), ProtocolMessage.t()) :: deliver_response()
  def deliver_message(server, message) do
    GenStateMachine.call(server, {:deliver_message, message}, @accept_channel_reply_timeout)
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
    data = %Data{
      channel: channel,
      application: application,
      user_ref: user_ref
    }

    Process.flag(:trap_exit, true)
    {:ok, :waiting, data}
  end

  ############################################
  ###           WAITING STATE             ####
  ### waiting state callbacks definitions ####
  def waiting(:enter, _old_state, data) do
    waiting_timeout = round(RulesProvider.get(@token_max_age) * 1000)
    {:keep_state, data, [{:state_timeout, waiting_timeout, :waiting_timeout}]}
  end

  def waiting(:state_timeout, :waiting_timeout, data) do
    {:stop, :normal, %{data | stop_cause: :waiting_timeout}}
  end

  def waiting({:call, from}, {:socket_connected, socket_pid}, data) do
    socket_ref = Process.monitor(socket_pid)
    new_data = %{data | socket: {socket_pid, socket_ref}}

    actions = [
      _reply = {:reply, from, :ok}
    ]

    {:next_state, :connected, new_data, actions}
  end

  def waiting(
        {:call, from},
        {:deliver_message, message},
        data
      ) do
    actions = [
      _reply = {:reply, from, :accepted_waiting},
      _postpone = :postpone
    ]

    new_data = save_pending_waiting_message(data, message)
    {:keep_state, new_data, actions}
  end

  def waiting({:timeout, {:redelivery, _ref}}, _, _data) do
    {:keep_state_and_data, :postpone}
  end

  def waiting({:call, _from}, _event, _data) do
    :keep_state_and_data
  end

  def waiting(:cast, _event, _data) do
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
      | pending_ack: Map.merge(pending_ack, data.pending_ack),
        pending_sending: Map.merge(pending_sending, data.pending_sending)
    }

    {:keep_state, new_data}
  end

  def waiting(:info, event, data) do
    IO.inspect({:info, event, data})
    :keep_state_and_data
  end

  ################### END######################
  ###           WAITING STATE             ####
  ############################################

  @type call() :: {:call, GenServer.from()}
  @type state_return() :: :gen_statem.event_handler_result(Data.t())

  def connected(:enter, _old_state, _data) do
    refresh_timeout = calculate_refresh_token_timeout()
    {:keep_state_and_data, [{:state_timeout, refresh_timeout, :refresh_token_timeout}]}
  end

  def connected(:state_timeout, :refresh_token_timeout, data) do
    refresh_timeout = calculate_refresh_token_timeout()
    message = new_token_message(data)

    {:deliver_msg, {_, ref}, _} = output = send_message(data, message)

    actions = [
      _redelivery_timeout =
        {{:timeout, {:redelivery, ref}}, RulesProvider.get(:initial_redelivery_time), 0},
      _refresh_timeout = {:state_timeout, refresh_timeout, :refresh_token_timeout}
    ]

    new_data = save_pending_message(data, output)
    {:keep_state, new_data, actions}
  end

  defp new_token_message(_data = %{application: app, channel: channel, user_ref: user}) do
    new_token = ChannelSenderEx.Core.ChannelIDGenerator.generate_token(channel, app, user)
    ProtocolMessage.of(UUID.uuid4(:hex), ":n_token", new_token)
  end

  @spec connected(call(), {:deliver_message, ProtocolMessage.t()}, Data.t()) :: state_return()
  def connected(
        {:call, from},
        {:deliver_message, message},
        data
      ) do
    {:deliver_msg, {_, ref}, _} = output = send_message(data, message)

    actions = [
      _reply = {:reply, from, :accepted_connected},
      _timeout = {{:timeout, {:redelivery, ref}}, RulesProvider.get(:initial_redelivery_time), 0}
    ]

    new_data =
      data
      |> save_pending_message(output)
      |> clear_pending_wait(message)

    {:keep_state, new_data, actions}
  end

  def connected(:info, {:ack, message_ref, _message_id}, data) do
    {_, new_data} = retrieve_pending_message(data, message_ref)

    actions = [
      _cancel_timer = {{:timeout, {:redelivery, message_ref}}, :cancel}
    ]

    {:keep_state, new_data, actions}
  end

  def connected({:timeout, {:redelivery, ref}}, retries, %{socket: {socket_pid, _}} = data) do
    {message, new_data} = retrieve_pending_message(data, ref)
    output = send(socket_pid, create_output_message(message, ref))

    actions = [
      _timeout =
        {{:timeout, {:redelivery, ref}}, RulesProvider.get(:initial_redelivery_time), retries + 1}
    ]

    {:keep_state, save_pending_message(new_data, output), actions}
  end

  # TODO: Check this logic
  def connected({:call, from}, {:socket_connected, socket_pid}, data = %{socket: {_, old_ref}}) do
    Process.demonitor(old_ref)
    socket_ref = Process.monitor(socket_pid)
    new_data = %{data | socket: {socket_pid, socket_ref}}

    actions = [
      _reply = {:reply, from, :ok}
    ]

    {:keep_state, new_data, actions}
  end

  def connected(:info, {:DOWN, ref, :process, _object, _reason}, %{socket: {_, ref}} = data) do
    new_data = %{data | socket: nil}

    actions = []

    {:next_state, :waiting, new_data, actions}
  end

  # TODO: test this scenario and register a callback to receive twins_last_letter in connected state
  def connected(
        :info,
        {:EXIT, _, {:name_conflict, {c_ref, _}, _, new_pid}},
        data = %{channel: c_ref}
      ) do
    send(new_pid, {:twins_last_letter, data})
    {:stop, :normal, %{data | stop_cause: :name_conflict}}
  end

  def connected(:info, _m = {:DOWN, _ref, :process, _object, _reason}, _data) do
    :keep_state_and_data
  end

  @impl true
  def terminate(reason, state, data) do
    IO.inspect({:terminating, reason, state, data})
    :ok
  end

  @compile {:inline, send_message: 2}
  defp send_message(%{socket: {socket_pid, _}}, message) do
    output = create_output_message(message)
    send(socket_pid, output)
  end

  @spec save_pending_message(Data.t(), output_message()) :: Data.t()
  @compile {:inline, save_pending_message: 2}
  defp save_pending_message(data = %{pending_ack: pending_ack}, {:deliver_msg, {_, ref}, message}) do
    %{data | pending_ack: Map.put(pending_ack, ref, message)}
  end

  @spec retrieve_pending_message(Data.t(), reference()) :: {ProtocolMessage.t(), Data.t()}
  @compile {:inline, retrieve_pending_message: 2}
  defp retrieve_pending_message(data = %{pending_ack: pending_ack}, ref) do
    {message, new_pending_ack} = Map.pop(pending_ack, ref)
    {message, %{data | pending_ack: new_pending_ack}}
  end

  @spec save_pending_waiting_message(Data.t(), ProtocolMessage.t()) :: Data.t()
  @compile {:inline, save_pending_waiting_message: 2}
  defp save_pending_waiting_message(data = %{pending_sending: pending_sending}, message) do
    %{
      data
      | pending_sending: Map.put(pending_sending, ProtocolMessage.message_id(message), message)
    }
  end

  @spec clear_pending_wait(Data.t(), ProtocolMessage.t()) :: Data.t()
  @compile {:inline, clear_pending_wait: 2}
  defp clear_pending_wait(data = %{pending_sending: %{}}, _), do: data

  defp clear_pending_wait(data = %{pending_sending: pending}, message) do
    %{data | pending_sending: Map.delete(pending, ProtocolMessage.message_id(message))}
  end

  @spec create_output_message(ProtocolMessage.t()) :: output_message()
  @compile {:inline, create_output_message: 1}
  defp create_output_message(message, ref \\ make_ref()) do
    {:deliver_msg, {self(), ref}, message}
  end

  @spec calculate_refresh_token_timeout() :: integer()
  @compile {:inline, calculate_refresh_token_timeout: 0}
  defp calculate_refresh_token_timeout() do
    token_validity = RulesProvider.get(@token_max_age)
    tolerance = RulesProvider.get(@min_disconnection_tolerance)
    min_timeout = token_validity / 2
    round(max(min_timeout, token_validity - tolerance) * 1000)
  end

  # 1. Build init
  # 2. Build start_link with distributed capabilities ? or configurable registry
  # 3. Draf Main states

  # {from = {pid, ref}, message = [message_id, _, _, _]}
end
