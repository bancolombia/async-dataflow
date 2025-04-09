defmodule ChannelSenderEx.Core.ChannelSupervisor do
  use DynamicSupervisor

  @moduledoc """
    Module to start supervised channels in a distributed way
  """
  require Logger

  alias ChannelSenderEx.Core.Channel
  import ChannelSenderEx.Core.Retry.ExponentialBackoff, only: [execute: 5]

  @max_retries 3
  @min_backoff 50
  @max_backoff 300

  def start_link(_) do
    res = DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
    Logger.info("Channel Supervisor Basic started")
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
    Logger.warning(fn -> "Channel Supervisor, starting channel with args: #{inspect(args)}" end)
    action_fn = fn _ -> start_channel_retried(args) end

    execute(@min_backoff, @max_backoff, @max_retries, action_fn, fn ->
      raise("Error creating channel")
    end)
  end

  @spec register_channel(channel_init_args()) :: any()
  def register_channel(args = {_channel_ref, _application, _user_ref, _meta}) do
    start_channel(args)
  end

  @spec register_channel_if_not_exists(channel_init_args()) :: any()
  def register_channel_if_not_exists(_args = {_channel_ref, _application, _user_ref, _meta}) do
    {:ok, self()}
  end

  @spec unregister_channel(channel_ref()) :: any()
  def unregister_channel(channel_ref) do
    :ok
  end

  @spec whereis_channel(channel_ref()) :: pid() | :undefined
  def whereis_channel(channel_ref) do
    case Registry.lookup(ChannelSenderEx.Registry, channel_ref) do
      [{pid, _}] when is_pid(pid) ->
        pid

      _other ->
        :undefined
    end
  end

  @spec app_members(application()) :: list()
  def app_members(application) do
    []
  end

  ## Internal functions

  @spec channel_child_spec(channel_init_args()) :: any()
  @compile {:inline, channel_child_spec: 1}
  def channel_child_spec(channel_args = {channel_ref, application, user_ref, _meta}) do
    channel_child_spec(channel_args, via_tuple(channel_ref, application, user_ref))
  end

  @compile {:inline, channel_child_spec: 2}
  def channel_child_spec(channel_args = {channel_ref, _application, _user_ref, _meta}, name) do
    %{
      id: "Channel_#{channel_ref}",
      start: {Channel, :start_link, [channel_args, [name: name]]},
      shutdown: get_shutdown_tolerance(),
      restart: :transient
    }
  end

  defp start_channel_retried(args = {channel_ref, _application, _user_ref, _meta}) do
    case DynamicSupervisor.start_child(__MODULE__, channel_child_spec(args)) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:error, reason} ->
        Logger.warning(
          "Error starting channel #{channel_ref}: #{inspect(reason)}, operation will be retried"
        )

        :retry
    end
  end

  defp via_tuple(ref, app, usr) do
    {:via, Registry, {ChannelSenderEx.Registry, ref, {app, usr}}}
  end

  defp get_shutdown_tolerance do
    RulesProvider.get(:channel_shutdown_tolerance)
  rescue
    _ -> 10_000
  end
end
