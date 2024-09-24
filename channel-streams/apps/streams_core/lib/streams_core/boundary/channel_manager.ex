defmodule StreamsCore.Boundary.ChannelManager do
  @moduledoc """
  Main abstraction for modeling an async communication channel(s) with an application.
  """
  use GenStateMachine, callback_mode: [:state_functions, :state_enter]
  require Logger
  import  Bitwise

  alias StreamsCore.Sender.Connector

  alias StreamsCore.Channel
  alias StreamsCore.CloudEvent

  @type channel_ref() :: String.t()
  @type channel_secret() :: String.t()

  @spec get_channel_info(:gen_statem.server_ref()) :: {:ok, any()} | {:error, reason :: term}
  def get_channel_info(server) do
    GenStateMachine.call(server, :channel_info)
  end

  @type deliver_response :: :ok
  @spec deliver_message(:gen_statem.server_ref(), CloudEvent.t()) :: deliver_response()
  def deliver_message(server, message) do
    GenStateMachine.cast(server, {:deliver_message, message})
  end

  def update(server, new_channel_data) do
    GenStateMachine.call(server, {:update_channel, new_channel_data})
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

    procs = Enum.map(channel.procs, fn ref ->
      Connector.start_router_process(ref.channel_ref, [])
    end)
    |> Enum.reduce(0, fn result, acc ->
      case result do
        {:ok, _} -> acc + 1
        _ -> acc
      end
    end)

    Logger.debug("started channel manager with: #{inspect(args)}, for [#{inspect(procs)}] adf channel sender reference(s).")

    {:ok, :open, args}
  end

  ################################################################################
  ###                             OPEN STATE                                  ####
  ###                   open state callbacks definitions                      ####
  ################################################################################

  def open(:enter, _old_state, _data) do
    # sets up process to validate channel state every 60 seconds + some drift
    {:keep_state_and_data, [{:state_timeout, 60_000 + rand_increment(1_000), :validate_state}]}
  end

  def open(
    {:call, from},
    :channel_info,
    data
  ) do
    {:keep_state_and_data, [{:reply, from, {:ok, data}}]}
  end

  # Delivers a cloud_event, performing any steps necesary prior to calling ADF Sender endpoint.
  def open(
        :cast,
        {:deliver_message, cloud_event},
        {channel, mutator} = _data
      ) do

    result = CloudEvent.mutate(cloud_event, mutator)
      |> call_send(channel)

    case result do
      {:error, _} ->
        :keep_state_and_data

      _ ->
        # updates chanel with timestamp of last processed message
        {:keep_state, {Channel.update_last_message(channel), mutator}}
    end
  end

  def open(
    {:call, from},
    {:update_channel, new_channel_data},
    {channel, mutator} = _data
  ) do

    case Channel.get_procs(new_channel_data) do
      {:error, :empty_refs} ->
        {:keep_state_and_data, [{:reply, from, {:error, :empty_refs}}]}

      {:ok, procs} ->
        {ch_ref, sec} = Enum.map(procs, fn ref -> {ref.channel_ref, ref.channel_secret} end)
          |> List.first()
        new_channel = Channel.update_credentials(channel, ch_ref, sec)
        Connector.start_router_process(ch_ref, [])
        Logger.debug("ChannelManager, new state: #{inspect(new_channel)}")
        {:keep_state, {new_channel, mutator}, [{:reply, from, {:ok, new_channel}}]}
    end
  end

  # Validates idling condition on an open channel. If channel is considered as being idle after a certain time frame
  # then is forced to close.
  def open(
    :state_timeout,
    :validate_state,
    {channel, _} = data
  ) do

    case Channel.check_state_inactivity(channel) do
      :noop -> {:keep_state_and_data, [{:state_timeout, 60_000 + rand_increment(1_000), :validate_state}]}
      :timeout -> {:next_state, :closed, data, []}
    end

  end

  # ------------------------------
  # Changes channel state to closed
  # ------------------------------
  def open(
        {:call, from},
        {:close_channel},
        {channel, _mutator} = _data
      ) do

#    {:ok, new_channel} = Channel.close(channel)

    {:next_state, :closed, {channel, nil}, [
      {:reply, from, :ok}
    ]}
  end

  defp call_send({:error, _reason} = result, channel) do
    Logger.error("Message not routeable to #{inspect(channel.procs)} due to error: #{inspect(result)}")
    result
  end

  defp call_send(_, %{status: :new} = _channel) do
    Logger.error("Channel status is :new, routing message is not posible.")
    {:error, :invalid_status, nil}
  end

  defp call_send({:ok, cloud_event}, %{status: :ready} = channel) do
    case Channel.prepare_messages(channel, cloud_event) do
      {:error, _} = err ->
        err

      {:ok, messages} ->
        route(messages)
    end
  end

  defp route(messages) do
    messages
    |> Stream.map(fn msg ->

      send_result = Connector.route_message(msg.channel_ref, msg)

      case send_result do
        {:ok, _} ->
          Logger.debug("Message routed to #{inspect(msg.channel_ref)}")
          {msg.channel_ref, :ok}

        {:error, reason} ->
          Logger.error("Message not routed to #{msg.channel_ref}, reason: #{inspect(reason)}")
          {msg.channel_ref, :error, reason}
      end
    end)
    |> Enum.to_list()
  end

  ################################################################################
  ###                             CLOSED STATE                                ####
  ###                   closed state callbacks definitions                    ####
  ################################################################################

  def closed(:enter, _old_state, {channel, _} = _data) do

    # close related routing processes
    procs = Enum.map(channel.procs, fn ref ->
      Connector.stop_router_process(ref.channel_ref, [])
    end)
    |> Enum.reduce(0, fn result, acc ->
      case result do
        :ok -> acc + 1
        _ -> acc
      end
    end)
    Logger.debug("ChannelManager, closed #{inspect(procs)} routing procs.")

    {:ok, new_channel} = Channel.close(channel)

    closing_timeout = 10 * 1000
    {:keep_state, {new_channel, nil}, [{:state_timeout, closing_timeout, :closing_timeout}]}
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

  @impl true
  def terminate(reason, state, {channel, _} = _data) do
    Logger.warning(
      "Channel with alias '#{channel.channel_alias}' is terminating. Reason: #{inspect(reason)}. Data: #{inspect(channel)}. State: #{inspect(state)}"
    )
  end

  defp rand_increment(n) do
    #  New delay chosen from [N, 3N], i.e. [0.5 * 2N, 1.5 * 2N]
    width = n <<< 1
    n + :rand.uniform(width + 1) - 1
  end

end
