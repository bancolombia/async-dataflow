defmodule ChannelSenderEx.Core.ChannelSupervisor do
  use DynamicSupervisor

  @moduledoc """
    Module to start supervised channels in a distributed way
  """
  require Logger

  alias ChannelSenderEx.Core.Channel
  alias ChannelSenderEx.Utils.CustomTelemetry
  import ChannelSenderEx.Core.Retry.ExponentialBackoff, only: [execute: 5]
  @max_retries 5
  @min_backoff 50
  @max_backoff 200

  def start_link(_) do
    res = DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
    Logger.info("Channel Supervisor started")
    res
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @type channel_ref :: String.t()
  @type application :: String.t()
  @type user_ref :: String.t()
  @type meta :: list()
  @type channel_init_args :: {channel_ref(), application(), user_ref(), meta()}

  @spec start_channel(channel_init_args()) :: any()
  def start_channel(args) do
    Logger.debug(fn -> "Channel Supervisor, starting channel with args: #{inspect(args)}" end)

    case DynamicSupervisor.start_child(__MODULE__, {Channel, args}) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_registered, pid}} ->
        {:ok, pid}

      {:error, reason} ->
        Logger.error(fn ->
          "Channel Supervisor, failed to register channel with args: #{inspect(args)}, reason: #{inspect(reason)}"
        end)

        {:error, reason}
    end
  end

  @spec register_channel(channel_init_args()) :: any()
  def register_channel(args = {channel_ref, _application, _user_ref, _meta}) do
    with {:ok, pid} <- start_channel(args),
         {:ok, true} <- put_retried(channel_ref, pid) do
      {:ok, pid}
    else
      {:error, reason} ->
        Logger.error(fn ->
          "Channel Supervisor, failed to register channel with args: #{inspect(args)}, reason: #{inspect(reason)}"
        end)

        {:error, reason}
    end
  end

  @spec start_channel_if_not_exists(channel_init_args()) :: any()
  def start_channel_if_not_exists(args = {channel_ref, _application, _user_ref, _meta}) do
    pid = whereis_channel(channel_ref)

    if pid == :undefined or not Channel.alive?(pid) do
      CustomTelemetry.execute_custom_event([:adf, :channel, :created_on_socket], %{count: 1})
      register_channel(args)
    else
      {:ok, pid}
    end
  end

  @spec register_channel_if_not_exists(channel_init_args()) :: any()
  def register_channel_if_not_exists(_args = {channel_ref, _application, _user_ref, _meta}) do
    case Cachex.get(:channels, channel_ref) do
      {:ok, pid} when is_pid(pid) ->
        register_if_not_running(channel_ref, pid, self())

      {:ok, nil} ->
        pid = self()

        Logger.debug(fn ->
          "Channel Supervisor, channel #{channel_ref} not exists : nil self #{inspect(pid)}"
        end)

        put_retried(channel_ref, pid)
        {:ok, pid}

      {:error, reason} ->
        Logger.error(fn ->
          "Channel Supervisor, failed to register channel #{channel_ref}, reason: #{inspect(reason)}"
        end)

        {:error, reason}
    end
  end

  @spec unregister_channel(channel_ref()) :: any()
  def unregister_channel(channel_ref) do
    Cachex.del(:channels, channel_ref)
  end

  @spec whereis_channel(channel_ref()) :: pid() | :undefined
  def whereis_channel(channel_ref) do
    case Cachex.get(:channels, channel_ref) do
      {:ok, pid} when is_pid(pid) ->
        Logger.debug(fn -> "Channel Supervisor, channel exists : #{inspect(pid)}" end)
        pid

      {:ok, nil} ->
        :undefined
    end
  end

  @spec app_members(application()) :: list()
  def app_members(_application) do
    []
  end

  defp register_if_not_running(channel_ref, pid, self_pid) do
    if Channel.alive?(pid) do
      Logger.debug(fn ->
        "Channel Supervisor, channel #{channel_ref} exists : #{inspect(pid)} self #{inspect(self_pid)}"
      end)

      {:ok, pid}
    else
      Logger.debug(fn ->
        "Channel Supervisor, channel #{channel_ref} not alive : #{inspect(pid)} self #{inspect(self_pid)}"
      end)

      put_retried(channel_ref, self_pid)
      {:ok, self_pid}
    end
  end

  defp put_retried(channel_ref, channel_pid) do
    action_fn = put_action(channel_ref, channel_pid)

    execute(@min_backoff, @max_backoff, @max_retries, action_fn, fn ->
      Logger.warning(fn ->
        "Channel Supervisor, could not save channel #{channel_ref} after #{@max_retries} retries"
      end)

      {:ok, true}
    end)
  end

  defp put_action(channel_ref, channel_pid) do
    fn delay ->
      put_action_delay(delay, channel_ref, channel_pid)
    end
  end

  defp put_action_delay(delay, channel_ref, channel_pid) do
    case Cachex.put(:channels, channel_ref, channel_pid) do
      {:ok, true} ->
        Logger.debug(fn ->
          "Channel Supervisor, channel #{channel_ref} saved in #{delay}"
        end)

        verify_or_retry(channel_ref)

      other ->
        Logger.debug(fn ->
          "Channel Supervisor, channel #{channel_ref} could not be saved in delay #{delay} -> #{inspect(other)}"
        end)

        :retry
    end
  end

  defp verify_or_retry(channel_ref) do
    case Cachex.get(:channels, channel_ref) do
      {:ok, pid} when is_pid(pid) ->
        Logger.debug(fn -> "Channel Supervisor, channel #{channel_ref} checked save ok" end)
        {:ok, true}

      other ->
        Logger.debug(fn ->
          "Channel Supervisor, channel #{channel_ref} checked save fail inspect #{other}"
        end)

        :retry
    end
  end
end
