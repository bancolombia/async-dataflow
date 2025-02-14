defmodule ChannelSenderEx.Persistence.NoopChannelPersistence do
  @behaviour ChannelSenderEx.Persistence.ChannelPersistenceBehavior

  alias ChannelSenderEx.Core.Channel.Data

  @impl true
  @spec save_channel_data(Data.t()) :: :ok
  def save_channel_data(_data = %Data{}), do: :ok

  @impl true
  @spec delete_channel_data(binary()) :: :ok
  def delete_channel_data(_channel_id), do: :ok

  @impl true
  @spec get_channel_data(binary()) :: {:ok, Data.t()} | {:error, :not_found}
  def get_channel_data(_channel_id), do: {:error, :not_found}

  @impl true
  @spec child_spec() :: [Supervisor.child_spec()] | []
  def child_spec(), do: []
end
