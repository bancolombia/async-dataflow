defmodule ChannelSenderEx.Core.MessageProcessSupervisor do
  @moduledoc """
    Module to start supervised message process in a distributed way to ensure message delivery.
  """
  use Horde.DynamicSupervisor
  require Logger

  alias ChannelSenderEx.Core.MessageProcess
  import ChannelSenderEx.Core.Retry.ExponentialBackoff, only: [execute: 5]
  @max_retries 3
  @min_backoff 50
  @max_backoff 300

  def start_link(_) do
    opts = [strategy: :one_for_one, shutdown: 1000, distribution_strategy: Horde.UniformRandomDistribution]
    result = Horde.DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
    Logger.debug("MessageProcessSupervisor: #{inspect(result)}")
    result
  end

  def init(init_arg) do
    [members: :auto]
    |> Keyword.merge(init_arg)
    |> Horde.DynamicSupervisor.init()
  end

  # defp members do
  #   [Node.self() | Node.list()]
  #   |> Enum.map(fn node -> {__MODULE__, node} end)
  # end

  @type channel_ref :: String.t()
  @type message_id :: String.t()
  @type channel_init_args :: {channel_ref(), message_id()}

  @spec start_message_process(channel_init_args()) :: any()
  def start_message_process(args) do
    spec = message_process_child_spec(args)
    action_fn = fn _ -> start_message_process_retried(spec) end

    execute(@min_backoff, @max_backoff, @max_retries, action_fn, fn ->
      raise("Error creating message process")
    end)
  end

  defp start_message_process_retried(child_specification = %{id: id}) do
    case Horde.DynamicSupervisor.start_child(__MODULE__, child_specification) do
      {:ok, pid} ->
        Logger.debug(fn -> "Message process #{id} started" end)
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:error, reason} ->
        Logger.warning(fn -> "Error starting message process #{id}: #{inspect(reason)}, operation will be retried" end)
        :retry
    end
  end

  defp message_process_child_spec(message_args = {_channel_ref, message_id}) do
    %{
      id: message_id,
      start: {MessageProcess, :start_link, [message_args]},
      shutdown: 2_000,
      restart: :transient
    }
  end

end
