defmodule ChannelSenderEx.Core.PubSub.PubSubCore do
  @moduledoc """
  Handles channel delivery and discovery logic
  """
  require Logger

  alias ChannelSenderEx.Core.{Channel, ChannelRegistry, ProtocolMessage}

  import ChannelSenderEx.Core.Retry.ExponentialBackoff, only: [execute: 5]

  @type channel_ref() :: String.t()

  @max_retries 10
  @min_backoff 50
  @max_backoff 2000

  @spec deliver_to_channel(channel_ref(), ProtocolMessage.t()) :: any()
  def deliver_to_channel(channel_ref, message) do
    action_fn = fn _ -> do_deliver_to_channel(channel_ref, message) end
    execute(@min_backoff, @max_backoff, @max_retries, action_fn, fn -> raise("No channel found") end)
  end

  def deliver_to_channels(app_ref, message) do
    action_fn = fn _ -> do_deliver_to_channels(app_ref, message) end
    execute(@min_backoff, @max_backoff, @max_retries, action_fn, fn -> raise("No channels found for requested app") end)
  end

  defp do_deliver_to_channel(channel_ref, message) do
    case ChannelRegistry.lookup_channel_addr(channel_ref) do
      pid when is_pid(pid) -> Channel.deliver_message(pid, message)
      :noproc ->
        Logger.warning("Channel #{channel_ref} not found, retrying message delivery request...")
        :retry
    end
  end

  defp do_deliver_to_channels(app_ref, message) do
    procs = ChannelRegistry.query(app_ref)
    case Enum.empty?(procs) do
      false ->
        procs
        |> Enum.map(fn {_, pid, {_, _}} -> Channel.deliver_message(pid, message) end)
      true ->
        Logger.warning("No Channels found for app '#{app_ref}', retrying message delivery request...")
        :retry
    end
  end
end
