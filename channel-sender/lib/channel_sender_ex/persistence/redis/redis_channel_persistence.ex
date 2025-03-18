defmodule ChannelSenderEx.Persistence.RedisChannelPersistence do
  @moduledoc false
  @behaviour ChannelSenderEx.Persistence.ChannelPersistenceBehavior

  alias ChannelSenderEx.Persistence.RedisSupervisor
  alias ChannelSenderEx.Core.ProtocolMessage

  require Logger

  @type channel :: String.t()
  @type socket :: String.t()
  @type message_id :: String.t()
  @type message :: ProtocolMessage.t()

  @impl true
  @spec save_channel(channel(), socket()) :: :ok
  def save_channel(channel, socket \\ "") do
      Logger.debug(fn -> "Redis: Saving channel [#{channel}] : socket[#{socket}]" end)
      ttl = get_channel_data_ttl()
      Redix.noreply_command(:redix_write, ["SETEX", "channel_#{channel}", ttl, socket])
      :ok
  rescue
    e ->
      Logger.error(fn -> "Redis: Error while saving channel data: #{inspect(e)}" end)
      :ok
  end

  @impl true
  @spec save_socket(channel(), socket()) :: :ok
  def save_socket(channel, socket) do
    Logger.debug(fn -> "Redis: Saving socket [#{socket}] : channel[#{channel}]" end)
    ttl = get_channel_data_ttl()
    Redix.noreply_pipeline(:redix_write, [
        ["SETEX", "channel_" <> channel, ttl, socket],
        ["SETEX", "socket_" <> socket, ttl, channel]
    ])
  rescue
    e ->
      Logger.error(fn -> "Redis: Error while saving socket-channel relation: #{inspect(e)}" end)
      :ok
  end

  @impl true
  @spec save_message(message_id(), any()) :: :ok
  def save_message(message_id, message) do
    Logger.debug(fn -> "Redis: Saving message [#{message_id}] : #{inspect(message)}" end)
    ttl = get_channel_data_ttl()
    Redix.noreply_command(:redix_write, ["SETEX", "message_" <> message_id, ttl, message])
  rescue
    e ->
      Logger.error(fn -> "Redis: Error while saving message: #{inspect(e)}" end)
      :ok
  end

  @impl true
  @spec delete_channel(channel(), socket()) :: :ok
  def delete_channel(channel, socket) do
    case socket do
      "" ->
        Redix.noreply_command(:redix_write, ["DEL", "channel_#{channel}"])
      _ ->
        Redix.noreply_pipeline(:redix_write, [
          ["DEL", "channel_" <> channel],
          ["DEL", "socket_" <> socket]
        ])
    end
  rescue
    e ->
      Logger.error(fn -> "Redis: Error while deleting channel data [#{channel}]: #{inspect(e)}" end)
      :ok
  end

  @impl true
  @spec delete_socket(socket(), channel()) :: :ok
  def delete_socket(socket, channel) do
    case channel do
      "" ->
        Redix.noreply_command(:redix_write, ["DEL", "socket_#{socket}"])
      _ ->
        Redix.noreply_pipeline(:redix_write, [
          ["DEL", "socket_" <> socket],
          ["SETEX", "channel_" <> channel, get_channel_data_ttl(), ""]
        ])
    end
  rescue
    e ->
      Logger.error(fn -> "Redis: Error while deleting socket data [#{socket}]: #{inspect(e)}" end)
      :ok
  end

  @impl true
  @spec delete_message(message_id()) :: :ok
  def delete_message(message_id) do
    Logger.debug(fn -> "Redis: Deleting message [#{message_id}]" end)
    Redix.noreply_command(:redix_write, ["DEL", "message_#{message_id}"])
  rescue
    e ->
      Logger.error(fn -> "Redis: Error while deleting message data [#{message_id}]: #{inspect(e)}" end)
      :ok
  end

  @impl true
  @spec get_channel(channel()) :: {:ok, socket()} | {:error, :not_found}
  def get_channel(channel) do
      lookup_key("channel_#{channel}")
  end

  @impl true
  @spec get_socket(socket()) :: {:ok, channel()} | {:error, :not_found}
  def get_socket(socket) do
    lookup_key("socket_#{socket}")
  end

  @impl true
  @spec get_message(message_id(), channel()) :: {:ok, list()}
  def get_message(message_id, channel_ref) do
    Redix.pipeline(:redix_read, [
      ["GET", "channel_#{channel_ref}"], # get socket id query
      ["GET", "message_#{message_id}"]
    ])
  rescue
    e ->
      Logger.error(fn -> "Redis: Error while getting message: #{inspect(e)}" end)
      {:error, :not_found}
  end

  def lookup_key(key) do
    Logger.debug(fn -> "Redis: Getting key: #{key}" end)
    with {:ok, data} when not is_nil(data) <- Redix.command(:redix_read, ["GET", key]) do
      {:ok, data}
    else
      _ ->
        Logger.debug(fn -> "Redis: Key not found for: #{key}" end)
        {:error, :not_found}
    end
  rescue
    e ->
      Logger.error(fn -> "Redis: Error while getting key: #{inspect(e)}" end)
      {:error, :not_found}
  end

  @impl true
  @spec child_spec() :: [Supervisor.child_spec()] | []
  def child_spec do
    cfg = Application.get_env(:channel_sender_ex, :persistence)
    Logger.info("Redis: channel persistence enabled with ttl: #{inspect(get_channel_data_ttl())}")
    [RedisSupervisor.spec(Keyword.get(cfg, :config, []))]
  end

  @compile {:inline, get_channel_data_ttl: 0}
  defp get_channel_data_ttl do
    Application.get_env(:channel_sender_ex, :persistence_ttl, 900)
  end

end
