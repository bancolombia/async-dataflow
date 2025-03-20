defmodule ChannelSenderEx.Core.PubSub.PubSubCore do
  @moduledoc """
  Handles channel delivery and discovery logic
  """
  require Logger

  alias ChannelSenderEx.Core.Channel
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Utils.CustomTelemetry
  import ChannelSenderEx.Core.Retry.ExponentialBackoff, only: [execute: 5]

  @type channel_ref() :: String.t()
  @type app_ref() :: String.t()
  @type delivery_result() :: %{accepted_waiting: number(), accepted_connected: number()}

  @max_retries 10
  @min_backoff 50
  @max_backoff 2000

  @doc """
  Delivers a message to a single channel associated with the given channel reference.
  If the channel is not found, the message is retried up to @max_retries times with exponential backoff.
  """
  @spec deliver_to_channel(channel_ref(), ProtocolMessage.t()) :: any()
  def deliver_to_channel(channel_ref, message) do
    action_fn = fn _ -> do_deliver_to_channel(channel_ref, message) end
    execute(@min_backoff, @max_backoff, @max_retries, action_fn, fn ->
      CustomTelemetry.execute_custom_event([:adf, :message, :nodelivered], %{count: 1})
      raise("No channel found")
    end)
  rescue
    e ->
      Logger.warning("Could not deliver message after #{@max_retries} retries, to channel: \"#{channel_ref}\". Cause: #{inspect(e)}")
      :error
  end

  @doc """
  Delivers a message to all channels associated with the given application reference. The message is delivered to each channel in a separate process.
  No retries are performed since the message is delivered to existing and queriyable channels at the given time.
  """
  @spec deliver_to_app_channels(app_ref(), ProtocolMessage.t()) :: delivery_result()
  def deliver_to_app_channels(app_ref, message) do
    Swarm.members(app_ref)
    |> Stream.map(fn pid -> Channel.deliver_message(pid, message) end)
    |> Enum.frequencies()
  end

  @doc """
  Delivers a message to all channels associated with the given user reference. The message is delivered to each channel in a separate process.
  No retries are performed since the message is delivered to existing and queriyable channels at the given time.
  """
  @spec deliver_to_user_channels(app_ref(), ProtocolMessage.t()) :: delivery_result()
  def deliver_to_user_channels(_user_ref, _message) do
    %{accepted_waiting: 0, accepted_connected: 0}
  end

  defp do_deliver_to_channel(channel_ref, message) do
    case Swarm.whereis_name(channel_ref) do
      pid when is_pid(pid) -> Channel.deliver_message(pid, message)
      :undefined ->
        :retry
    end
  end

  def delete_channel(channel_ref) do
    action_fn = fn _ -> do_delete_channel(channel_ref) end
    execute(@min_backoff, @max_backoff, @max_retries, action_fn, fn ->
      Logger.warning("Could not delete channel #{channel_ref} after #{@max_retries} retries")
      :ok
    end)
  end

  def do_delete_channel(channel_ref) do
    case  Swarm.whereis_name(channel_ref) do
      pid when is_pid(pid) -> Channel.stop(pid)
      :undefined ->
        :retry
    end
  end
end
