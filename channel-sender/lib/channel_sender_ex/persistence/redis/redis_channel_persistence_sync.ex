defmodule ChannelSenderEx.Persistence.RedisChannelPersistenceSync do
  @moduledoc false
  @behaviour ChannelSenderEx.Persistence.ChannelPersistenceBehavior

  alias ChannelSenderEx.Persistence.RedisSupervisor
  alias ChannelSenderEx.Core.ProtocolMessage

  require Logger

  @type channel :: String.t()
  @type socket :: String.t()
  @type channel_ref :: String.t()
  @type message_id :: String.t()
  @type message :: ProtocolMessage.t()

  @impl true
  @spec save_channel(channel(), socket()) :: :ok
  def save_channel(channel, socket \\ "") do
    Logger.debug(fn -> "Redis: Saving channel [#{channel}] : socket[#{socket}]" end)
    ttl = get_channel_data_ttl()
    Redix.command!(:redix_write, ["SETEX", "channel_#{channel}", ttl, socket])
    :ok
  rescue
    e ->
      Logger.error(fn -> "Redis: Error while saving channel data: #{inspect(e)}" end)
      :ok
  end

  @impl true
  @spec save_socket(channel(), socket()) :: :ok
  def save_socket(channel, socket) do
    Logger.debug(fn ->
      "Redis: Saving both relations for socket [#{socket}] : channel[#{channel}]"
    end)

    ttl = get_channel_data_ttl()

    Redix.pipeline!(:redix_write, [
      ["SETEX", "channel_" <> channel, ttl, socket],
      ["SETEX", "socket_" <> socket, ttl, channel]
    ])
  rescue
    e ->
      Logger.error(fn -> "Redis: Error while saving socket-channel relation: #{inspect(e)}" end)
      :ok
  end

  @impl true
  @spec save_message(channel_ref(), message_id(), any()) :: :ok
  def save_message(channel_ref, message_id, message) do
    Logger.debug(fn -> "Redis: Saving message [#{channel_ref}:#{message_id}] : #{inspect(message)}" end)
    ttl = get_channel_data_ttl()
    Redix.pipeline!(:redix_write, [
      ["HSET",  "msgs_" <> channel_ref, message_id, message],
      ["HEXPIRE", "msgs_" <> channel_ref, ttl, "FIELDS", "1", message_id]
    ])
  rescue
    e ->
      Logger.error(fn -> "Redis: Error while saving message: #{inspect(e)}" end)
      :ok
  end

  @impl true
  @spec delete_channel(channel(), socket()) :: :ok
  def delete_channel(channel, socket) do
    Logger.debug(fn -> "Redis: deleting channel[#{channel}] and socket[#{socket}]" end)

    case socket do
      "" ->
        Redix.command!(:redix_write, ["DEL", "channel_#{channel}"])

      _ ->
        Redix.pipeline!(:redix_write, [
          ["DEL", "channel_" <> channel],
          ["DEL", "socket_" <> socket]
        ])
    end
  rescue
    e ->
      Logger.error(fn ->
        "Redis: Error while deleting channel data [#{channel}]: #{inspect(e)}"
      end)

      :ok
  end

  @impl true
  @spec delete_socket(socket(), channel()) :: :ok
  def delete_socket(socket, channel) do
    Logger.debug(fn -> "Redis: deleting socket[#{socket}] of chanel[#{channel}]" end)

    case channel do
      "" ->
        Redix.command!(:redix_write, ["DEL", "socket_#{socket}"])

      _ ->
        Redix.pipeline!(:redix_write, [
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
  @spec delete_message(channel_ref(), message_id()) :: :ok
  def delete_message(channel_ref, message_id) do
    Logger.debug(fn -> "Redis: Deleting message [#{message_id}]" end)
    Redix.command!(:redix_write, ["HDEL", "msgs_" <> channel_ref, message_id])
  rescue
    e ->
      Logger.error(fn ->
        "Redis: Error while deleting message data [#{message_id}]: #{inspect(e)}"
      end)
      :ok
  end

  @impl true
  @spec ack_message(socket(), message_id()) :: :ok
  def ack_message(socket, message_id) do
    get_socket(socket)
    |> case do
      {:ok, channel_ref} ->
        Logger.debug(fn -> "Redis: Acknowledging message [#{channel_ref}:#{message_id}]" end)
        Redix.command!(:redix_write, ["HDEL", "msgs_" <> channel_ref, message_id])

      {:error, reason} ->
        Logger.error(fn -> "Redis: Error while acknowledging message: #{inspect(reason)}" end)
    end
  rescue
    e ->
      Logger.error(fn ->
        "Redis: Error while ack message [#{message_id}] with socket [#{socket}]: #{inspect(e)}"
      end)

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
      # get socket id query
      ["GET", "channel_#{channel_ref}"],
      ["GET", "message_#{message_id}"]
    ])
  rescue
    e ->
      Logger.error(fn -> "Redis: Error while getting message: #{inspect(e)}" end)
      {:error, :not_found}
  end

  @impl true
  @spec get_messages(channel()) :: {:ok, list()}
  def get_messages(channel_ref) do
    Redix.pipeline(:redix_read, [
      ["GET", "channel_#{channel_ref}"], # obtains socket
      ["HGETALL", "msgs_#{channel_ref}"] # obtains raw messages
    ])
  rescue
    e ->
      Logger.error(fn -> "Redis: Error while getting messages: #{inspect(e)}" end)
      {:error, :not_found}
  end

  def lookup_key(key) do
    Logger.debug(fn -> "Redis: Getting key: #{key}" end)

    case Redix.command(:redix_read, ["GET", key]) do
      {:ok, nil} ->
        Logger.debug(fn -> "Redis: Key not found for: #{key}" end)
        {:error, :not_found}

      {:ok, data} ->
        {:ok, data}

      error ->
        Logger.debug(fn -> "Redis: error getting key: #{key} -> #{inspect(error)}" end)
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

  @impl true
  @spec health :: :ok | {:error, any()}
  def health() do
    case Redix.command!(:redix_read, ["PING"]) do
      "PONG" -> :ok
      error -> {:error, error}
    end
  end

  @compile {:inline, get_channel_data_ttl: 0}
  defp get_channel_data_ttl do
    Application.get_env(:channel_sender_ex, :persistence_ttl, 900)
  end
end
