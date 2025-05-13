defmodule ChannelSenderEx.Core.ChannelSupervisor do
  use DynamicSupervisor

  @moduledoc """
    Module to start supervised channels in a distributed way
  """
  require Logger

  alias ChannelSenderEx.Core.Channel

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
         {:ok, true} <- Cachex.put(:channels, channel_ref, pid) do
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

    if pid == :undefined or not Process.alive?(pid) do
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
        register_if_not_running(channel_ref, pid)

      {:ok, nil} ->
        pid = self()

        Logger.debug(fn ->
          "Channel Supervisor, channel #{channel_ref} not exists : nil self #{inspect(pid)}"
        end)

        Cachex.put(:channels, channel_ref, pid)
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

  defp register_if_not_running(channel_ref, pid) do
    self_pid = self()

    if Process.alive?(pid) do
      Logger.debug(fn ->
        "Channel Supervisor, channel #{channel_ref} exists : #{inspect(pid)} self #{inspect(self_pid)}"
      end)

      {:ok, pid}
    else
      Logger.debug(fn ->
        "Channel Supervisor, channel #{channel_ref} not alive : #{inspect(pid)} self #{inspect(self_pid)}"
      end)

      Cachex.put(:channels, channel_ref, self_pid)
      {:ok, self_pid}
    end
  end
end
