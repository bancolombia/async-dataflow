defmodule ChannelSenderEx.Persistence.RedisChannelPersistence do
  @behaviour ChannelSenderEx.Persistence.ChannelPersistenceBehavior

  alias ChannelSenderEx.Persistence.RedisSupervisor
  alias ChannelSenderEx.Core.Channel.Data
  require Logger

  @impl true
  @spec save_channel_data(Data.t()) :: :ok
  def save_channel_data(data = %Data{channel: channel_id}) do
    ttl = get_channel_data_ttl()

    serializable = %{
      data
      | pending_ack: to_map(data.pending_ack),
        pending_sending: to_map(data.pending_sending)
    }

    Redix.noreply_command(:redix_write, ["SETEX", channel_id, ttl, Jason.encode!(serializable)])
  end

  @impl true
  @spec delete_channel_data(binary()) :: :ok
  def delete_channel_data(channel_id) do
    Redix.noreply_command(:redix_write, ["DEL", channel_id])
  end

  @impl true
  @spec get_channel_data(binary()) :: {:ok, Data.t()} | {:error, :not_found}
  def get_channel_data(channel_id) do
    with {:ok, data} when not is_nil(data) <- Redix.command(:redix_read, ["GET", channel_id]),
         {:ok, map} <- Jason.decode(data) do
      parsed =
        Map.put(map, "pending_ack", from_map(Map.get(map, "pending_ack")))
        |> Map.put("pending_sending", from_map(Map.get(map, "pending_sending")))
        |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)

      {:ok, struct(Data, parsed)}
    else
      _ -> {:error, :not_found}
    end
  end

  @impl true
  @spec child_spec() :: [Supervisor.child_spec()] | []
  def child_spec() do
    cfg = Application.get_env(:channel_sender_ex, :persistence)
    Logger.info("RedisChannelPersistence enabled with ttl: #{inspect(get_channel_data_ttl())}")
    [RedisSupervisor.spec(Keyword.get(cfg, :config, []))]
  end

  defp get_channel_data_ttl() do
    Application.get_env(:channel_sender_ex, :persistence_ttl)
  end

  defp to_map({map, list}) do
    Map.new(map, fn {_k, v} -> tuple_to_map(v) end)
    |> Map.put_new("keys", list)
  end

  defp from_map(map) do
    list = Map.get(map, "keys", [])
    result_map = Map.delete(map, "keys") |> Enum.map(fn {k, v} -> {k, map_to_tuple(v)} end) |> Enum.into(%{})
    {result_map, list}
  end

  defp tuple_to_map({message_id, correlation_id, event_name, message_data, timestamp}) do
    %{
      message_id: message_id,
      correlation_id: correlation_id,
      event_name: event_name,
      message_data: message_data,
      timestamp: timestamp
    }
  end

  defp map_to_tuple(%{
         "message_id" => message_id,
         "correlation_id" => correlation_id,
         "event_name" => event_name,
         "message_data" => message_data,
         "timestamp" => timestamp
       }) do
    {message_id, correlation_id, event_name, message_data, timestamp}
  end
end
