defmodule ChannelSenderEx.Persistence.RedisChannelPersistence do
  @moduledoc false
  @behaviour ChannelSenderEx.Persistence.ChannelPersistenceBehavior

  alias ChannelSenderEx.Core.BoundedMap
  alias ChannelSenderEx.Core.Data
  alias ChannelSenderEx.Persistence.RedisSupervisor
  alias ChannelSenderEx.Utils.CustomTelemetry

  require Logger

  @impl true
  @spec save_channel_data(Data.t()) :: :ok
  def save_channel_data(data = %Data{channel: channel_ref}) do
      Logger.debug(fn -> "Saving channel data: #{inspect(data)}" end)

      ttl = get_channel_data_ttl()

      serializable = %{
        data
        | pending: BoundedMap.to_map(data.pending)
      }
      |> Jason.encode!()

      CustomTelemetry.execute_custom_event([:adf, :persistence, :save], %{count: 1})

      Redix.noreply_command(:redix_write, ["SETEX", "channel_" <> channel_ref, ttl, serializable])
      case data.socket do
        nil -> :ok
        socket ->
          Redix.noreply_command(:redix_write, ["SETEX", "socket_" <> socket, ttl, data.channel])
      end
    rescue
      e ->
        Logger.error(fn -> "Error while saving channel data: #{inspect(e)}" end)
        :ok
  end

  @impl true
  @spec save_socket_data(binary(), binary()) :: :ok
  def save_socket_data(channel_ref, socket_id) do
      Logger.debug(fn -> "Saving socket-channel relation: #{socket_id} - #{channel_ref}" end)
      ttl = get_channel_data_ttl()
      Redix.noreply_command(:redix_write, ["SETEX", "socket_" <> socket_id, ttl, channel_ref])
    rescue
      e ->
        Logger.error(fn -> "Error while saving socket-channel relation: #{inspect(e)}" end)
        :ok
  end

  @impl true
  @spec delete_channel_data(binary()) :: :ok
  def delete_channel_data(channel_ref) do
    CustomTelemetry.execute_custom_event([:adf, :persistence, :delete], %{count: 1})
    Redix.noreply_command(:redix_write, ["DEL", channel_ref])
  rescue
    e ->
      Logger.error(fn -> "Error while deleting channel/socket data [#{channel_ref}]: #{inspect(e)}" end)
      :ok
  end

  @impl true
  @spec get_channel_data(binary()) :: {:ok, Data.t()} | {:error, :not_found}
  def get_channel_data(channel_ref) do
    if String.starts_with?(channel_ref, "socket_") do
      lookup_socket(channel_ref)
    else
      lookup_channel(channel_ref)
    end
  end

  def lookup_channel(channel_ref) do
    Logger.debug(fn -> "Getting channel data for channel: #{channel_ref}" end)
    with {:ok, data} when not is_nil(data) <- Redix.command(:redix_read, ["GET", channel_ref]),
        {:ok, map} <- Jason.decode(data) do
      parsed =
        Map.put(map, "pending", BoundedMap.from_map(Map.get(map, "pending")))
        |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)

      Logger.debug(fn -> "Got channel data: #{inspect(parsed)}" end)
      CustomTelemetry.execute_custom_event([:adf, :persistence, :get], %{count: 1})
      {:ok, struct(Data, parsed)}
    else
      _ ->
        Logger.debug(fn -> "Channel data not found for: #{channel_ref}" end)
        CustomTelemetry.execute_custom_event([:adf, :persistence, :getmiss], %{count: 1})
        {:error, :not_found}
    end
  rescue
    e ->
      CustomTelemetry.execute_custom_event([:adf, :persistence, :getmiss], %{count: 1})
      Logger.error(fn -> "Error while getting channel data: #{inspect(e)}" end)
      {:error, :not_found}
  end

  def lookup_socket(socket_id) do
    Logger.debug(fn -> "Getting data for socket id: #{socket_id}" end)
    with {:ok, data} when not is_nil(data) <- Redix.command(:redix_read, ["GET", socket_id]) do
      Logger.debug(fn -> "Got socket data: #{data}" end)
      # CustomTelemetry.execute_custom_event([:adf, :persistence, :get], %{count: 1})
      {:ok, data}
    else
      _ ->
        Logger.debug(fn -> "Socket data not found for: #{socket_id}" end)
        # CustomTelemetry.execute_custom_event([:adf, :persistence, :getmiss], %{count: 1})
        {:error, :not_found}
    end
  rescue
    e ->
      # CustomTelemetry.execute_custom_event([:adf, :persistence, :getmiss], %{count: 1})
      Logger.error(fn -> "Error while getting socket data: #{inspect(e)}" end)
      {:error, :not_found}
  end

  @impl true
  @spec child_spec() :: [Supervisor.child_spec()] | []
  def child_spec do
    cfg = Application.get_env(:channel_sender_ex, :persistence)
    Logger.info("RedisChannelPersistence enabled with ttl: #{inspect(get_channel_data_ttl())}")
    [RedisSupervisor.spec(Keyword.get(cfg, :config, []))]
  end

  @compile {:inline, get_channel_data_ttl: 0}
  defp get_channel_data_ttl do
    Application.get_env(:channel_sender_ex, :persistence_ttl)
  end

end
