defmodule ChannelSenderEx.Persistence.ChannelPersistence do
  @moduledoc """
  This module is responsible for persisting the channel data.
  """

  @behaviour ChannelSenderEx.Persistence.ChannelPersistenceBehavior

  @spec save_channel_data(ChannelSenderEx.Channel.t()) :: :ok
  def save_channel_data(channel) do
    imp().save_channel_data(channel)
  end

  @spec get_channel_data(binary()) :: {:ok, ChannelSenderEx.Channel.t()} | {:error, :not_found}
  def get_channel_data(channel_id) do
    imp().get_channel_data(channel_id)
  end

  @spec child_spec() :: [Supervisor.child_spec()]
  def child_spec() do
    if enabled?() do
      imp().child_spec()
    else
      []
    end
  end

  def enabled?() do
    Application.get_env(:channel_sender_ex, :persistence)
    |> Keyword.get(:enabled, false)
  end

  defp imp() do
    type =
      Application.get_env(:channel_sender_ex, :persistence)
      |> Keyword.get(:type, [])

    case type do
      :redis -> ChannelSenderEx.Persistence.RedisChannelPersistence
      _ -> ChannelSenderEx.Persistence.ChannelPersistence
    end
  end
end
