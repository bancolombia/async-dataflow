defmodule BridgeCore.Boundary.ChannelManager do
  @moduledoc """
  Main abstraction for modeling an async communication channel(s) with an application.
  """
  use GenStateMachine, callback_mode: [:state_functions, :state_enter]
  require Logger

  alias BridgeCore.CloudEvent
  alias BridgeCore.Channel
  alias AdfSenderConnector.Message

  @type channel_ref() :: String.t()
  @type channel_secret() :: String.t()

  @spec get_channel_info(:gen_statem.server_ref()) :: :ok | {:error, reason :: term}
  def get_channel_info(server) do
    GenStateMachine.call(server, :channel_info)
  end

  @type deliver_response :: :ok
  @spec deliver_message(:gen_statem.server_ref(), CloudEvent.t()) :: deliver_response()
  def deliver_message(server, message) do
    GenStateMachine.cast(server, {:deliver_message, message})
  end

  def update(server, message) do
    GenStateMachine.call(server, {:update_channel, message})
  end

  @spec close_channel(:gen_statem.server_ref()) :: :ok | {:error, reason :: term}
  def close_channel(server) do
    GenStateMachine.call(server, {:close_channel})
  end

  @spec start_link(Channel.t()) :: :gen_statem.start_ret()

  @doc """
  Starts the state machine.
  """
  def start_link(args, opts \\ []) do
    GenStateMachine.start_link(__MODULE__, args, opts)
  end

  @impl GenStateMachine
  @doc false
  def init({channel, _mutator} = args) do
    Process.flag(:trap_exit, true)

    Enum.map(channel.procs, fn {ch_ref, _} ->
      AdfSenderConnector.start_router_process(ch_ref, [])
    end)

    Logger.debug("new channel manager : #{inspect(args)} ")

    {:ok, :open, args}
  end

  #########################################
  ###           OPEN STATE             ####
  ### open state callbacks definitions ####

  def open(:enter, _old_state, _data) do
    :keep_state_and_data
  end

  def open(
    {:call, from},
    :channel_info,
    data
  ) do
    {:keep_state_and_data, [{:reply, from, {:ok, data}}]}
  end

  @doc """
  Delivers a cloud_event, performing any steps necesary prior to calling ADF Sender endpoint.
  """
  def open(
        :cast,
        {:deliver_message, cloud_event},
        {channel, mutator} = _data
      ) do

    mutate_event(cloud_event, mutator)
      |> call_send(channel)

    :keep_state_and_data
  end

  def open(
    {:call, from},
    {:update_channel, channel_param},
    {channel, mutator} = _data
  ) do

    new_procs = Enum.dedup(channel_param.procs ++ channel.procs)
    new_channel = %{ channel | procs: new_procs, updated_at: DateTime.utc_now() }

    Logger.debug("ChannelManager, new state: #{inspect(new_channel)}")

    {ch_ref, _} = List.first(new_channel.procs)
    AdfSenderConnector.start_router_process(ch_ref, [])

    {:keep_state, {new_channel, mutator}, [{:reply, from, {:ok, new_channel}}]}

  end

  # ------------------------------
  # Changes channel state to closed
  # ------------------------------
  def open(
        {:call, from},
        {:close_channel},
        {channel, _mutator} = _data
      ) do

    {:ok, new_channel} = Channel.close(channel)

    Logger.debug("Channel changing to status closed, #{inspect(new_channel)}")

    {:next_state, :closed, {new_channel, nil}, [
      {:reply, from, :ok}
    ]}
  end

  defp mutate_event(cloud_event, mutator) do
    cloud_event
    |> mutator.mutate
    |> (fn result ->
          case result do
            {:ok, _mutated} ->
              Logger.debug("Cloud event mutated!")
              result

            {:error, reason} ->
              Logger.error("Message mutation error. #{inspect(reason)}")
              # raise "Error performing mutations on event..."
              {:error, reason}
          end
        end).()
  end

  defp call_send({:error, _reason} = result, channel) do
    Logger.error("Message not routeable to #{inspect(channel.procs)} due to error: #{inspect(result)}")
    result
  end

  defp call_send(_, %{status: :new} = _channel) do
    Logger.error("Channel status is :new, routing message is not posible.")
    {:error, :invalid_status, nil}
  end

  # defp call_send(_, %{status: :closed} = _channel) do
  #   Logger.error("Channel status is :closed, routing message is not posible.")
  #   {:error, :invalid_status, nil}
  # end

  defp call_send({:ok, cloud_event}, %{status: :ready} = channel) do

    with {:ok, _procs} <- check_channel_procs(channel),
          {:ok, _verified_event } <- check_cloud_event(cloud_event) do

        Stream.map(channel.procs, fn {channel_ref, _} ->
          Message.new(channel_ref, cloud_event.id, cloud_event.id, Map.from_struct(cloud_event), cloud_event.type)
        end) |>
        Stream.map(fn msg ->
          send_result = AdfSenderConnector.route_message(msg.channel_ref, msg.event_name, msg)
          case send_result do
            {:ok, _} ->
              Logger.debug("Message routed to #{inspect(msg.channel_ref)}")
              {:ok, msg.channel_ref}

            {:error, reason} ->
              Logger.error("Message not routed to #{msg.channel_ref}, reason: #{inspect(reason)}")
              {:error, reason, msg.channel_ref}
          end
        end) |>
        Enum.to_list()

      else
        {:error, :empty_refs} = err->
          Logger.error("channel_ref is empty or unknown. Routing messages is not posible. #{inspect(cloud_event)}")
          err

        {:error, :invalid_message} = err ->
          Logger.error("Invalid or nil cloud_event. Routing is not posible. #{inspect(cloud_event)}")
          err
    end
  end

  defp check_channel_procs(channel) do
    case channel.procs do
      nil ->
        {:error, :empty_refs}

      [] ->
        {:error, :empty_refs}
      _ ->
        {:ok, channel.procs}
    end
  end

  defp check_cloud_event(cloud_event) do
    case cloud_event do
      nil ->
        {:error, :invalid_message}
      _ ->
        {:ok, cloud_event}
    end
  end

  ###########################################
  ###           CLOSED STATE             ####
  ### closed state callbacks definitions ####

  def closed(:enter, _old_state, data) do
    # :keep_state_and_data
    closing_timeout = 10 * 1000
    {:keep_state, data, [{:state_timeout, closing_timeout, :closing_timeout}]}
  end

  def closed(
    {:call, from},
    :channel_info,
    data
  ) do
    {:keep_state_and_data, [{:reply, from, {:ok, data}}]}
  end

  def closed(:state_timeout, :closing_timeout, data) do
    {:stop, :shutdown, data}
  end

  def closed(
        {:call, from},
        {:close_channel},
        _data
      ) do
    {:keep_state_and_data, [{:reply, from, {:error, :alreadyclosed}}]}
  end

  def closed(
        :cast,
        {:deliver_message, cloud_event},
        {channel, _} = _data
      ) do
    Logger.warning("Channel with alias '#{channel.channel_alias}' is closed. Cloud Message will not be routed: #{inspect(cloud_event)}")
    :keep_state_and_data
  end

  def closed(
    :info,
    _old_state,
    _data
  ) do
    :keep_state_and_data
  end

  @impl true
  def terminate(reason, state, {channel, _} = _data) do
    Logger.warning(
      "Channel with alias '#{channel.channel_alias}' is terminating. Reason: #{inspect(reason)}. Data: #{inspect(channel)}. State: #{inspect(state)}"
    )
  end

end
