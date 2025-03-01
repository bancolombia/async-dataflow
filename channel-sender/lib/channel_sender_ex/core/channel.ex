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
  alias ChannelSenderEx.Persistence.ChannelPersistence
  alias ChannelSenderEx.Utils.CustomTelemetry
  import ChannelSenderEx.Core.Retry.ExponentialBackoff, only: [exp_back_off: 4]

  @on_connected_channel_reply_timeout 2000
  @millis_to_seconds 1000
  @default_token_age_seconds 900
  @default_redelivery_time_millis 900
  @default_max_pending_queue 100
  @default_max_backoff_redelivery_millis 1_700

  @type msg_tuple() :: ProtocolMessage.t()
  @type deliver_msg() :: {:deliver_msg, {pid(), String.t()}, msg_tuple()}
  @type pending() :: BoundedMap.t()
  @type deliver_response :: :accepted

  defmodule Data do
    @moduledoc """
    Data module stores the information for the server data
    """
    @type t() :: %ChannelSenderEx.Core.Channel.Data{
            channel: String.t(),
            application: String.t(),
            socket: {pid(), reference()},
            pending: ChannelSenderEx.Core.Channel.pending(),
            stop_cause: atom(),
            socket_stop_cause: atom(),
            user_ref: String.t(),
            meta: map()
          }

    @derive {Jason.Encoder, only: [:channel, :application, :pending, :user_ref, :meta]}
    defstruct channel: "",
              application: "",
              socket: nil,
              pending: BoundedMap.new(),
              stop_cause: nil,
              socket_stop_cause: nil,
              user_ref: "",
              meta: nil

    def new(channel, application, user_ref, meta \\ %{}) do
      %Data{
        channel: channel,
        application: application,
        socket: nil,
        pending: BoundedMap.new(),
        stop_cause: nil,
        socket_stop_cause: nil,
        user_ref: user_ref,
        meta: meta
      }
    end

    def put_in_meta(data, key, value) do
      %{data | meta: Map.put(data.meta, key, value)}
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
  @spec deliver_message(:gen_statem.server_ref(), ProtocolMessage.t()) :: deliver_response()
  def deliver_message(server, message) do
    GenStateMachine.cast(server, {:deliver_message, message})
    :accepted
  end

  @spec stop(atom() | pid() | {atom(), any()} | {:via, atom(), any()}) :: any()
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
    Process.flag(:trap_exit, true)
    Task.start(fn ->
      Logger.info(fn -> "Channel #{channel} starting" end)
      CustomTelemetry.execute_custom_event([:adf, :channel], %{count: 1})
    end)
    {:ok, :waiting, Data.new(channel, application, user_ref, meta)}
  end

  ############################################
  ###           WAITING STATE             ####
  ### waiting state callbacks definitions ####
  def waiting(:enter, old_state, data) do
    load_state_from_external(data, old_state)
    |> decide_next_state_from_waiting
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
    Logger.debug(fn -> "Channel #{data.channel} finished waiting for a socket connection and/or authentication" end)
    {:next_state, :closed, %{data | stop_cause: :waiting_timeout}}
  end

  def waiting({:call, from}, {:socket_connected, socket_pid}, data) do
    Logger.debug(fn -> """
      Channel #{data.channel} received socket connected notification from
      Socket pid: #{inspect(socket_pid)} and authenticated. Leaving waiting state.
      """
    end)

    {:next_state,
      :connected,
      %{data | socket: {socket_pid, Process.monitor(socket_pid)}, socket_stop_cause: nil},
      [
        _reply = {:reply, from, :ok}
      ]
    }
  end

  ## Handle the case when a message delivery is requested in the waiting state. In this case
  ## the message is saved in the pending_sending map.
  def waiting(
        :cast,
        {:deliver_message, message},
        data
      ) do

    Logger.debug(fn -> "Channel #{data.channel} received a message while waiting for authentication" end)

    {:keep_state,
      save_pending(message, data)
      |> persist_state(),
      []
    }
  end

  def waiting({:timeout, {:redelivery, _ref}}, _, _data) do
    {:keep_state_and_data, :postpone}
  end

  def waiting({:timeout, {:resend, _}}, _retries, _data) do
    :keep_state_and_data
  end

  def waiting({:call, _from}, _event, _data) do
    :keep_state_and_data
  end

  def waiting(
        :info,
        {:EXIT, _, {:name_conflict, {c_ref, _}, _, new_pid}},
        data = %{channel: c_ref}
      ) do
    Logger.warning(fn -> "Channel #{data.channel}, stopping process #{inspect(self())} in status :waiting due to :name_conflict, and starting new process #{inspect(new_pid)}" end)
    send(new_pid, {:twins_last_letter, data})
    {:stop, :normal, %{data | stop_cause: :name_conflict}}
  end

  def waiting(
        :info,
        {:twins_last_letter, %{pending: pending}},
        data
      ) do
    {:keep_state,
      %{ data | pending: BoundedMap.merge(pending, data.pending)}
      |> persist_state()}
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
    Logger.info(fn -> "Channel #{data.channel} entering connected state" end)

    actions = [
      {:state_timeout, calculate_refresh_token_timeout(), :refresh_token_timeout},
    ] ++ build_actions_for_pending(data)

    {:keep_state_and_data, actions}
  end

  def connected({:call, from}, {:socket_connected, socket_pid}, data = %{socket: {old_socket_pid, old_socket_ref}}) do
    Process.demonitor(old_socket_ref)
    send(old_socket_pid, :terminate_socket)
    Logger.debug(fn -> "Channel #{data.channel} overwritting socket pid." end)
    {:keep_state,
      %{data | socket: {socket_pid, Process.monitor(socket_pid)}, socket_stop_cause: nil},
      [
        _reply = {:reply, from, :ok}
      ]
    }
  end

  def connected(:state_timeout, :refresh_token_timeout, data) do
    send_message(data, new_token_message(data))
    |> save_pending(data)
    |> handle_post_deliver_token()
  end

  ## Handle the case when a message delivery is requested.
  #@spec connected(call(), {:deliver_message, ProtocolMessage.t()}, Data.t()) :: state_return()
  def connected(:cast, {:deliver_message, protocol_msg}, data) do
    send_message(data, protocol_msg)
      |> save_pending(data)
      |> handle_post_deliver()
  end

  ## Handle the case when a message is acknowledged by the client.
  def connected(:info, {:ack, message_ref, message_id}, data) do
    Logger.debug(fn -> "Channel #{data.channel} recv ack msg #{message_id}" end)
    case retrieve_pending(data, message_ref) do
      {:noop, _} ->
        {:keep_state_and_data, [{{:timeout, {:redelivery, message_ref}}, :cancel}]}

      {_, new_data} ->
        persist_state(new_data)
        {:keep_state, new_data, [{{:timeout, {:redelivery, message_ref}}, :cancel}]}
    end
  end

  ## This is basically a message re-delivery timer. It is triggered when a message is requested to be delivered.
  ## And it will continue to be executed until the message is acknowledged by the client.
  def connected({:timeout, {:redelivery, ref}}, retries, data) do
    retrieve_pending(data, ref)
      |> process_pending(retries, ref)
  end

  ## Handle info notification when socket process terminates. This method is called because the socket is monitored.
  ## via Process.monitor(socket_pid) in the waited/connected state.
  def connected(:info, {:DOWN, _ref, :process, _object, reason}, data) do
    Logger.warning(fn -> "Channel #{data.channel} detected socket close/disconnection. Will enter :waiting state" end)
    {:next_state, :waiting, %{data | socket: nil, socket_stop_cause: reason}, []}
  end

  # test this scenario and register a callback to receive twins_last_letter in connected state
  def connected(
        :info,
        {:EXIT, _, {:name_conflict, {c_ref, _}, _, new_pid}},
        data = %{channel: c_ref}
      ) do
        Logger.warning(fn ->
          "Channel #{data.channel}, stopping process #{inspect(self())} in status :waiting due to :name_conflict, and starting new process #{inspect(new_pid)}"
        end)
    send(new_pid, {:twins_last_letter, data})
    {:stop, :normal, %{data | stop_cause: :name_conflict}}
  end

  # capture shutdown signal
  def connected(:info, {:EXIT, from_pid, :shutdown}, data) do
    source_process = Process.info(from_pid)
    Logger.info(fn -> "Channel #{inspect(data)} received shutdown signal: #{inspect(source_process)}" end)
    :keep_state_and_data
  end

  # capture any other info message
  def connected(
    :info,
    info_payload,
    data
  ) do
    Logger.warning(fn -> "Channel #{data.channel} receceived unknown info message #{inspect(info_payload)}" end)
    :keep_state_and_data
  end

  def connected({:call, from}, :stop, data) do
    Logger.debug(fn -> "Channel #{data.channel} stopping, reason: :explicit_close" end)
    {:next_state, :closed,
      %{data | stop_cause: :explicit_close},
      [
        _reply = {:reply, from, :ok}
      ]
    }
  end

  defp new_token_message(_data = %{application: app, channel: channel, user_ref: user}) do
    ProtocolMessage.of(UUID.uuid4(:hex), ":n_token",
      ChannelIDGenerator.generate_token(channel, app, user))
  end

  ############################################
  ###           CLOSED STATE              ####
  ############################################
  def closed(:enter, _old_state, data) do
    Logger.info(fn -> "Channel #{data.channel} entering closed state" end)
    {:stop, :normal, data}
  end

  @impl true
  def terminate(reason, state, data) do
    CustomTelemetry.execute_custom_event([:adf, :channel], %{count: -1})
    msg = fn -> """
    Channel #{data.channel} terminating, from state #{inspect(state)} and reason #{inspect(reason)}. Data: #{inspect(data)}
    """ end
    if reason == :normal do
      Logger.log(:info, msg)
      Task.start(fn -> ChannelPersistence.delete_channel_data(data.channel) end)
    else
      persist_state(data)
      Logger.log(:warning, msg)
    end
    :ok
  end

  #########################################
  ###      Support functions           ####
  #########################################

  @compile {:inline, send_message: 2}
  @spec send_message(Data.t(), msg_tuple()) :: msg_tuple()
  defp send_message(%{socket: {socket_pid, _}}, message) do
    CustomTelemetry.execute_custom_event([:adf, :message, :delivered], %{count: 1})
    send(socket_pid, create_output_message(message))
    message
  end

  defp handle_post_deliver({ref, data}) do
    {:keep_state, persist_state(data),
      [_timeout = {{:timeout, {:redelivery, ref}},
        get_param(:initial_redelivery_time, @default_redelivery_time_millis), 0}]
    }
  end

  defp handle_post_deliver_token({msg_id, new_data}) do
    {:keep_state,
      new_data,
      [
        _redelivery_timeout =
          {{:timeout, {:redelivery, msg_id}},
            get_param(:initial_redelivery_time, @default_redelivery_time_millis), 0},
        _refresh_timeout = {:state_timeout,
          calculate_refresh_token_timeout(), :refresh_token_timeout}
      ]}
  end

  @spec retrieve_pending(Data.t(), reference()) :: {ProtocolMessage.t() | :noop, Data.t()}
  @compile {:inline, retrieve_pending: 2}
  defp retrieve_pending(data = %{pending: pending}, ref) do
    case BoundedMap.size(pending) do
      0 -> {:noop, data}
      _ ->
        case BoundedMap.pop(pending, ref) do
          {:noop, _} ->
            Logger.warning(fn -> "Channel #{data.channel} received ack for unknown message ref #{inspect(ref)}" end)
            {:noop, data}
          {message, new_pending} ->
            {message, %{data | pending: new_pending}}
        end
    end
  end

  #@spec save_pending(ProtocolMessage.t(), Data.t()) :: Data.t()
  # @compile {:inline, save_pending: 2}
  defp save_pending(message = {msg_id, _, _, _, _}, data = %{pending: pending}) do
    Logger.debug(fn -> "Channel #{data.channel} saving pending msg #{msg_id}" end)
    {msg_id, %{
      data
      | pending: BoundedMap.put(pending, msg_id, message, get_param(:max_pending_queue,
          @default_max_pending_queue))
    }}
  end

  defp process_pending({:noop, data}, _retries, ref) do
    Logger.warning(fn -> "Channel #{data.channel} received redelivery timeout for unknown message ref #{inspect(ref)}" end)
    :keep_state_and_data
  end

  defp process_pending({message = {message_id, _, _, _, _}, data}, retries, ref) do
    max_unacknowledged_retries = get_param(:max_unacknowledged_retries, 20)
    case retries do
      r when r >= max_unacknowledged_retries ->
        Logger.warning(fn -> "Channel #{data.channel} reached max retries for message #{inspect(message_id)}" end)
        {:keep_state, persist_state(data)}

      _ ->
        send_message(data, message)
        Logger.debug(fn ->
          "Channel #{data.channel} re-delivered message #{message_id} (retry ##{retries + 1})..."
        end)
        actions = [
          _timeout =
            {{:timeout, {:redelivery, ref}}, calculate_next_redelivery_time(retries), retries + 1}
        ]
        {:keep_state_and_data, actions}
    end
  end

  @compile {:inline, create_output_message: 1}
  @spec create_output_message(msg_tuple(), any() | nil) :: deliver_msg()
  defp create_output_message(message = {message_id, _, _, _, _}, _msg_id \\ nil) do
    {:deliver_msg, {self(), message_id}, message}
  end

  defp persist_state({_msg_id, data}) do
    persist_state(data)
  end

  defp persist_state(data) do
    Task.start(fn -> ChannelPersistence.save_channel_data(data) end)
    data
  end

  defp calculate_next_redelivery_time(retries) do
    round(exp_back_off(get_param(:initial_redelivery_time, @default_redelivery_time_millis),
      @default_max_backoff_redelivery_millis, retries, 0.2))
  end

  @spec calculate_refresh_token_timeout() :: integer()
  @compile {:inline, calculate_refresh_token_timeout: 0}
  defp calculate_refresh_token_timeout do
    token_validity = get_param(:max_age, @default_token_age_seconds)
    tolerance = get_param(:min_disconnection_tolerance, 50)
    min_timeout = token_validity / 2
    round(max(min_timeout, token_validity - tolerance) * @millis_to_seconds)
  end

  defp estimate_process_wait_time(data) do
    # when is a new socket connection this will resolve false
    case socket_clean_disconnection?(data) do
      true ->
        round(get_param(:channel_shutdown_on_clean_close, 30) * @millis_to_seconds)
      false ->
        # this time will also apply when socket the first time connected
        round(get_param(:channel_shutdown_on_disconnection, 300) * @millis_to_seconds)
    end
  end

  defp socket_clean_disconnection?(data) do
    case data.socket_stop_cause do
      :normal -> true
      {:remote, 1000, _} -> true
      _ -> false
    end
  end

  defp load_state_from_external(channel, from_state) when from_state == :waiting do
    Logger.debug(fn -> "Channel #{channel.channel} searching data in persistence." end)
    case ChannelPersistence.get_channel_data(channel.channel) do
      {:ok, loaded_data} ->
        Logger.debug(fn -> "Channel #{channel.channel} loaded state sucessfully" end)
        loaded_data
      {:error, _} ->
        Logger.debug(fn -> "Channel #{channel.channel} not present in external state. Starting fresh." end)
        channel
    end
  end

  defp load_state_from_external(channel, _from_state) do
    Logger.debug(fn -> "Channel #{channel.channel} not searching data in persistence." end)
    channel
  end

  defp decide_next_state_from_waiting(channel_data) do
    case estimate_process_wait_time(channel_data) do
      0 ->
        Logger.info(fn -> "Channel #{channel_data.channel} will not remain in waiting state due calculated wait time is 0. Stopping now." end)
        #{:next_state, :closed, %{channel_data | stop_cause: :waiting_time_zero}}
        {:keep_state,
          %{channel_data | socket_stop_cause: :waiting_time_zero},
          [{:state_timeout, 0, :waiting_timeout}]}

      waiting ->
        Logger.info(fn ->
          "Channel #{inspect(channel_data.channel)} entering waiting state. Expecting a socket connection/authentication. max wait time: #{waiting} ms"
        end)
        {:keep_state,
          %{channel_data | socket_stop_cause: nil},
          [{:state_timeout, waiting, :waiting_timeout}]}
    end
  end

  defp build_actions_for_pending(data) do
    case BoundedMap.size(data.pending) do
      0 ->
        []
      _ ->
        Logger.debug(fn -> "Channel #{data.channel} has pending messages to send" end)
        Enum.map(BoundedMap.to_map(data.pending), fn {_k, v} -> List.to_tuple(v) end)
        |> Enum.map(fn {msg_id, _, _, _, _} ->
          {{:timeout, {:redelivery, msg_id}},
            redelidery_time_minus_drift(get_param(:initial_redelivery_time, @default_redelivery_time_millis)),
            0}
        end)
    end
  end

  defp redelidery_time_minus_drift(time) do
    time + :rand.uniform(100)
  end

  defp get_param(param, def) do
    RulesProvider.get(param)
  rescue
    _e -> def
  end

end
