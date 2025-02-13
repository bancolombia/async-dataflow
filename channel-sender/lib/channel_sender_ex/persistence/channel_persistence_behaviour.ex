defmodule ChannelSenderEx.Persistence.ChannelPersistenceBehavior do
  @callback save_channel_data(ChannelSenderEx.Core.Channel.Data.t()) :: :ok
  @callback get_channel_data(binary()) ::
              {:ok, ChannelSenderEx.Core.Channel.Data.t()} | {:error, :not_found}
  @callback child_spec() :: [Supervisor.child_spec()]
end
