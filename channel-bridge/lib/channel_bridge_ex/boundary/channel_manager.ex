defmodule ChannelBridgeEx.Boundary.ChannelManager do
  @moduledoc """
  Main abstraction for modeling an async communication channel(s) with an application.
  """
  use GenStateMachine, callback_mode: [:state_functions, :state_enter]
  require Logger

  alias AdfSenderConnector.Message
  alias ChannelBridgeEx.Core.CloudEvent
  alias ChannelBridgeEx.Core.Channel
  # alias ChannelBridgeEx.Core.RulesProvider

  @default_channel_reply_timeout 2000

  @type channel_ref() :: String.t()
  @type channel_secret() :: String.t()

  @type open_channel_response :: {channel_ref(), channel_secret()} | {:error, reason :: term}

  @spec open_channel(:gen_statem.server_ref()) :: open_channel_response()
  def open_channel(server, timeout \\ @default_channel_reply_timeout) do
    GenStateMachine.call(server, {:open_channel}, timeout)
  end

  @spec close_channel(:gen_statem.server_ref()) :: :ok | {:error, reason :: term}
  def close_channel(server) do
    GenStateMachine.call(server, {:close_channel})
  end

  @type deliver_response :: :accepted | :rejected
  @spec deliver_message(:gen_statem.server_ref(), CloudEvent.t()) :: deliver_response()
  def deliver_message(server, message) do
    case is_nil(message) do
      true ->
        :ignored

      false ->
        GenStateMachine.cast(server, {:deliver_message, message})
        :accepted
    end
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
  def init(args) do
    Process.flag(:trap_exit, true)
    new_args = Map.put(args, "mutator", Application.get_env(:channel_bridge_ex, :event_mutator))
    {:ok, :waiting, new_args}
  end

  ############################################
  ###            WAITING STATE            ####
  ### waiting state callbacks definitions ####

  def waiting(:enter, _old_state, data) do
    waiting_timeout = 30 * 1000
    {:keep_state, data, [{:state_timeout, waiting_timeout, :waiting_timeout}]}
  end

  def waiting(:state_timeout, :waiting_timeout, data) do
    {:stop, :shutdown, data}
  end

  ############################################
  ###           WAITING STATE             ####
  ### waiting state callbacks definitions ####

  @doc """
  Opens the Channel. This 'opening' is not actually opening any tcp socket, instead is requesting a new channel
  registration with ADF Sender. The actual opening of the tcp socket is performed by the ADF sender client with
  the credentials provided as result of this operation.
  """
  def waiting(
        {:call, from},
        {:open_channel},
        data
      ) do
    channel = data["channel"]

    case AdfSenderConnector.channel_registration(channel.application_ref.id, channel.user_ref.id) do
      {:ok, adf_channel_response} ->
        new_channel =
          Channel.open(
            channel,
            adf_channel_response["channel_ref"],
            adf_channel_response["channel_secret"]
          )

        new_data = Map.replace!(data, "channel", new_channel)

        Logger.debug("channel is registered #{new_channel.channel_ref}")

        {:next_state, :open, new_data,
         [
           {:reply, from,
            %{
              "session_tracker" => new_channel.channel_alias,
              "channel_ref" => new_channel.channel_ref,
              "channel_secret" => new_channel.channel_secret
            }}
         ]}

      {:error, reason} ->
        Logger.error("Channel registration failed: #{inspect(reason)}")
        new_channel = Channel.set_status(channel, :error, reason)

        new_data = Map.replace!(data, "channel", new_channel)
        {:keep_state, new_data, [{:reply, from, {:error, new_channel.reason}}]}
    end
  end

  def waiting(
        :cast,
        {:deliver_message, cloud_event},
        _data
      ) do
    Logger.warn(
      "Channel is not yet opened. Cloud Message will not be routed: #{inspect(cloud_event)}"
    )

    :keep_state_and_data
  end

  def waiting(
        {:call, from},
        {:close_channel},
        _data
      ) do
    {:keep_state_and_data, [{:reply, from, {:error, "channel never opened"}}]}
  end

  #########################################
  ###           OPEN STATE             ####
  ### open state callbacks definitions ####

  def open(:enter, _old_state, _data) do
    :keep_state_and_data
  end

  def open(
        {:call, from},
        {:open_channel},
        _data
      ) do
    {:keep_state_and_data, [{:reply, from, {:error, :alreadyopen}}]}
  end

  @doc """
  Delivers a cloud_event, performing any steps necesary prior to calling ADF Sender endpoint.
  """
  def open(
        :cast,
        {:deliver_message, cloud_event},
        data
      ) do
    channel = data["channel"]
    mutator = data["mutator"]

    # ----------------------------------------------------------------
    # The delivery task is done under a supervisor in order to provide
    # retry functionality
    Task.Supervisor.start_child(
      ADFSender.TaskSupervisor,
      fn ->
        # perform mutations on cloud event if needed
        mutated_event =
          cloud_event
          |> mutator.mutate
          |> (fn result ->
                case result do
                  {:ok, mutated} ->
                    mutated

                  {:error, reason} ->
                    Logger.error("Message mutation error. #{inspect(reason)}")
                    raise "Error performing mutations on event..."
                end
              end).()

        send_result =
          AdfSenderConnector.route_message(channel.channel_ref,
            mutated_event.type, to_notification_message(channel, mutated_event))

        case send_result do
          :ok ->
            Logger.debug("Success: Message routing requested.")

          :error ->
            Logger.error("Error: Message routing failed!")
            raise "Error calling ADF sender"
        end
      end,
      restart: :transient
    )
    # End of delivery task---------------------------------------------

    :keep_state_and_data
  end

  # ------------------------------
  # Closes (unregisters) a channel
  # ------------------------------
  def open(
        {:call, from},
        {:close_channel},
        data
      ) do
    channel = data["channel"]

    case Channel.close(channel) do
      {:ok, closed_channel} ->
        new_data = Map.replace!(data, "channel", closed_channel)

        {:next_state, :closed, new_data,
         [
           {:reply, from, :ok}
         ]}

      {:error, reason} ->
        {:keep_state_and_data, [{:reply, from, {:error, reason}}]}
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
        {:call, from},
        {:open_channel},
        _data
      ) do
    {:keep_state_and_data, [{:reply, from, {:error, "channel was closed, cannot re-open"}}]}
  end

  def closed(
        :cast,
        {:deliver_message, cloud_event},
        _data
      ) do
    Logger.warn("Channel is closing. Cloud Message will not be routed: #{inspect(cloud_event)}")
    :keep_state_and_data
  end

  @impl true
  def terminate(reason, _state, data) do
    channel = data["channel"]

    Logger.warn(
      "Channel [#{channel.channel_alias}] is terminating. Reason: #{inspect(reason)}. Data: #{inspect(channel)}"
    )
  end

  defp to_notification_message(channel, event) do
    Message.new(channel.channel_ref, event.id, event.id, Map.from_struct(event), event.type)
  end

end
