defmodule ChannelSenderEx.Core.ChannelSupervisorPg do
  use DynamicSupervisor

  @moduledoc """
    Module to start supervised channels in a distributed way using :pg module
  """
  require Logger

  alias ChannelSenderEx.Core.Channel
  alias ChannelSenderEx.Utils.CustomTelemetry

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
    case start_channel(args) do
      {:ok, pid} ->
        register_pid(channel_ref, pid)

      {:error, reason} ->
        Logger.error(fn ->
          "Channel Supervisor, failed to register channel with args: #{inspect(args)}, reason: #{inspect(reason)}"
        end)

        {:error, reason}
    end
  end

  @spec whereis_channel(channel_ref()) :: pid() | :undefined
  def whereis_channel(channel_ref) do
    case :pg.get_members(channel_ref) do
      [] ->
        :undefined

      [pid | _tail] ->
        pid
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

  def register_channel_if_not_exists(channel_ref) do
    pid = whereis_channel(channel_ref)

    cond do
      pid == :undefined ->
        register_pid(channel_ref, self())

      Channel.alive?(pid) ->
        {:ok, pid}

      true ->
        unregister_channel(channel_ref, pid)
        register_pid(channel_ref, self())
    end
  end

  def register_pid(channel_ref, pid) do
    :pg.join(channel_ref, pid)
    {:ok, pid}
  end

  def unregister_channel(channel_ref, pid) do
    :pg.leave(channel_ref, pid)
  end

  @spec app_members(application()) :: list()
  def app_members(_application) do
    # :pg.get_members(application)
    []
  end
end
