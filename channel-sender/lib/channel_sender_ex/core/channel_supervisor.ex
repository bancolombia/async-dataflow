defmodule ChannelSenderEx.Core.ChannelSupervisor do
  @moduledoc """
    Module to start supervised channels in a distributed way
  """
  use Horde.DynamicSupervisor
  require Logger

  alias ChannelSenderEx.Core.Channel
  alias ChannelSenderEx.Core.RulesProvider
  import ChannelSenderEx.Core.Retry.ExponentialBackoff, only: [execute: 5]
  @max_retries 3
  @min_backoff 50
  @max_backoff 300

  @shards 3

  def start_link(args) do
    opts = [strategy: :one_for_one, shutdown: 1000]
    result = Horde.DynamicSupervisor.start_link(__MODULE__, opts, name: args[:name])
    Logger.debug("ChannelSupervisor: #{inspect(result)}")
    result
  end

  def init(init_arg) do
    [members: members()]
    |> Keyword.merge(init_arg)
    |> Horde.DynamicSupervisor.init()
  end

  defp members do
    [Node.self() | Node.list()]
    |> Enum.map(fn node -> {__MODULE__, node} end)
  end

  @type channel_ref :: String.t()
  @type application :: String.t()
  @type user_ref :: String.t()
  @type meta :: list()
  @type channel_init_args :: {channel_ref(), application(), user_ref(), meta()}

  @spec start_channel(channel_init_args()) :: any()
  def start_channel(args) do
    action_fn = fn _ -> start_channel_retried(args) end

    execute(@min_backoff, @max_backoff, @max_retries, action_fn, fn ->
      raise("Error creating channel")
    end)
  end

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

    shard = :erlang.phash2(channel_ref, @shards)
    module = case shard do
      0 -> ChannelSenderEx.Core.ChannelSupervisor1
      1 -> ChannelSenderEx.Core.ChannelSupervisor2
      2 -> ChannelSenderEx.Core.ChannelSupervisor3
    end

    case Horde.DynamicSupervisor.start_child(module, channel_child_spec(args)) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:error, reason} ->
        Logger.warning("Error starting channel #{channel_ref}: #{inspect(reason)}, operation will be retried")
        :retry
    end
  end

  defp via_tuple(ref, app, usr) do
    shard = :erlang.phash2(ref, @shards)
    module = case shard do
      0 -> ChannelSenderEx.Core.ChannelRegistry1
      1 -> ChannelSenderEx.Core.ChannelRegistry2
      2 -> ChannelSenderEx.Core.ChannelRegistry3
    end
    {:via, Horde.Registry, {module, ref, {app, usr}}}
  end

  defp get_shutdown_tolerance do
    RulesProvider.get(:channel_shutdown_tolerance)
  rescue
    _ -> 10_000
  end
end
