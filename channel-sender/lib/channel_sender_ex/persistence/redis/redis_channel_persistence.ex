defmodule ChannelSenderEx.Persistence.RedisChannelPersistence do
  @behaviour ChannelSenderEx.Persistence.ChannelPersistenceBehavior

  alias ChannelSenderEx.Persistence.RedisSupervisor
  alias ChannelSenderEx.Core.Channel.Data

  @impl true
  @spec save_channel_data(Data.t()) :: :ok
  def save_channel_data(data = %Data{channel: channel_id}) do
    Redix.noreply_command(:redix_write, ["SETEX", channel_id, 50, Jason.encode!(data)])
  end

  @impl true
  @spec get_channel_data(binary()) :: {:ok, Data.t()} | {:error, :not_found}
  def get_channel_data(channel_id) do
    with {:ok, data} when not is_nil(data) <- Redix.command(:redix_read, ["GET", channel_id]),
         {:ok, map} <- Jason.decode(data, keys: :atoms!) do
      {:ok, struct(Data, map)}
    else
      _ -> {:error, :not_found}
    end
  end

  @impl true
  @spec child_spec() :: [Supervisor.child_spec()]
  def child_spec() do
    cfg = Application.get_env(:channel_sender_ex, :persistence)

    if Keyword.get(cfg, :enabled, false) do
      [RedisSupervisor.spec(Keyword.get(cfg, :config, []))]
    else
      []
    end
  end
end
