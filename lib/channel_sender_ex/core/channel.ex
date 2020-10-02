defmodule ChannelSenderEx.Core.Channel do
  @moduledoc """
  Main abstraction for modeling and active or temporarily idle async communication channel with an user.
  """
  use GenStateMachine, callback_mode: [:state_functions, :state_enter]
  require Logger
  alias ChannelSenderEx.Core.ProtocolMessage

  # Max allowed time in waiting before terminate the channel
#  @waiting_timeout Application.get_env(:channel_sender_ex, :channel_waiting_timeout, 30)
  @initial_redelivery_time Application.get_env(:channel_sender_ex, :initial_redelivery_time, 850)
#  @message_time_to_live Application.get_env(:channel_sender_ex, :message_time_to_live, 8000)
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

  defmodule Data do
    @moduledoc """
    Data module stores the information for the server data
    """
    @type t() :: %ChannelSenderEx.Core.Channel.Data{
            channel: String.t(),
            application: String.t(),
            socket: {pid(), reference()},
            pending_ack: ChannelSenderEx.Core.Channel.pending_ack(),
            pending_sending: %{optional(String.t()) => ProtocolMessage.t()},
            user_ref: String.t()
          }

    defstruct channel: "",
              application: "",
              socket: nil,
              pending_ack: %{},
              pending_sending: %{},
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

    {:ok, :waiting, data}
  end

  def waiting(:enter, _old_state, data) do
    {:keep_state, data, [{:state_timeout, 3000, :waiting_timeout}]}
  end

  def waiting(:state_timeout, :waiting_timeout, data) do
    IO.inspect({"In Timeout", :waiting_timeout, data})
    :keep_state_and_data
  end

  def waiting({:call, from}, {:socket_connected, socket_pid}, data) do
    socket_ref = Process.monitor(socket_pid)
    new_data = %{data | socket: {socket_pid, socket_ref}}

    actions = [
      _reply = {:reply, from, :ok}
    ]

    {:next_state, :connected, new_data, actions}
  end

  @spec waiting(call(), {:deliver_message, ProtocolMessage.t()}, Data.t()) :: state_return()
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

  def waiting({:call, from}, event, data) do
    IO.inspect({"In Call", {:call, from}, event, data})
    :keep_state_and_data
  end

  def waiting(:cast, event, data) do
    IO.inspect({"In Cast", :cast, event, data})
    :keep_state_and_data
  end

  def waiting(:info, event, data) do
    IO.inspect({"In info", :cast, event, data})
    :keep_state_and_data
  end

  @type call() :: {:call, GenServer.from()}
  @type state_return() :: :gen_statem.event_handler_result(Data.t())

  def connected(:enter, _old_state, data) do
    {:keep_state, data, _actions = []}
  end

  @spec connected(call(), {:deliver_message, ProtocolMessage.t()}, Data.t()) :: state_return()
  def connected(
        {:call, from},
        {:deliver_message, message},
        data
      ) do
    {{_, ref}, _} = output = send_message(data, message)

    actions = [
      _reply = {:reply, from, :accepted_connected},
      _timeout = {{:timeout, {:redelivery, ref}}, @initial_redelivery_time, 0}
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
      _cancel_timer = {{:timeout, message_ref}, :cancel}
    ]

    {:keep_state, new_data, actions}
  end

  def connected({:timeout, {:redelivery, ref}}, retries, %{socket: {socket_pid, _}} = data) do
    {message, new_data} = retrieve_pending_message(data, ref)

    output = send(socket_pid, create_output_message(message, ref))

    actions = [
      _timeout = {{:timeout, {:redelivery, ref}}, @initial_redelivery_time, retries + 1}
    ]

    {:keep_state, save_pending_message(new_data, output), actions}
  end

  def connected(:info, {:DOWN, ref, :process, _object, _reason}, %{socket: {_, ref}} = data) do
    new_data = %{data | socket: nil}

    actions = []

    {:next_state, :waiting, new_data, actions}
  end

  def connected(:info, m = {:DOWN, _ref, :process, _object, _reason}, _data) do
    IO.inspect("Ignoring #{inspect(m)}")
    :keep_state_and_data
  end

  @compile {:inline, send_message: 2}
  defp send_message(%{socket: {socket_pid, _}}, message) do
    output = create_output_message(message)
    send(socket_pid, output)
  end

  @spec save_pending_message(Data.t(), output_message()) :: Data.t()
  @compile {:inline, save_pending_message: 2}
  defp save_pending_message(data = %{pending_ack: pending_ack}, {{_, ref}, message}) do
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
    %{data | pending_ack: Map.put(pending_sending, ProtocolMessage.message_id(message), message)}
  end

  @spec clear_pending_wait(Data.t(), ProtocolMessage.t()) :: Data.t()
  @compile {:inline, clear_pending_wait: 2}
  defp clear_pending_wait(data = %{pending_sending: %{}}, _), do: data

  defp clear_pending_wait(data = %{pending_sending: pending}, message) do
    %{data | pending_ack: Map.delete(pending, ProtocolMessage.message_id(message))}
  end

  @spec create_output_message(ProtocolMessage.t()) :: output_message()
  @compile {:inline, create_output_message: 1}
  defp create_output_message(message, ref \\ make_ref()) do
    {{self(), ref}, message}
  end

  # 1. Build init
  # 2. Build start_link with distributed capabilities ? or configurable registry
  # 3. Draf Main states

  # {from = {pid, ref}, message = [message_id, _, _, _]}
end
