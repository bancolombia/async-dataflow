defmodule ChannelSenderEx.Core.MessageProcessSupervisor do
  @moduledoc """
    Module to start supervised message process in a distributed way to ensure message delivery.
  """
  use DynamicSupervisor
  require Logger

  alias ChannelSenderEx.Core.MessageProcess

  def start_link(_) do
    res = DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
    Logger.info("Channel Supervisor started")
    res
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @type channel_ref :: String.t()
  @type message_id :: String.t()
  @type process_init_args :: {channel_ref(), message_id()}

  @spec start_process(process_init_args()) :: any()
  def start_process(args) do
    DynamicSupervisor.start_child(__MODULE__, {MessageProcess, args})
  end

  @spec start_process_cluster(process_init_args()) :: any()
  def start_process_cluster(args = {_channel_ref, message_id}) do
    case Swarm.register_name(message_id, __MODULE__, :start_process, [args]) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_registered, pid}} ->
        {:ok, pid}

      {:error, reason} ->
        Logger.error(fn ->
          "Message Supervisor, failed to register msg process with args: #{inspect(args)}, reason: #{inspect(reason)}"
        end)

        {:error, reason}
    end
  end

end
