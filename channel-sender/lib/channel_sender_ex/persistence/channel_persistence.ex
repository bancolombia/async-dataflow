defmodule ChannelSenderEx.Persistence.ChannelPersistence do
  @moduledoc """
  This module is responsible for persisting the channel data.
  """
  alias ChannelSenderEx.Core.Data
  alias ChannelSenderEx.Persistence.NoopChannelPersistence
  alias ChannelSenderEx.Persistence.RedisChannelPersistence

  @behaviour ChannelSenderEx.Persistence.ChannelPersistenceBehavior

  @spec save_channel_data(Data.t()) :: :ok
  def save_channel_data(channel) do
    imp().save_channel_data(channel)
  end

  @spec save_socket_data(binary(), binary()) :: :ok
  def save_socket_data(channel_ref, socket_id) do
    imp().save_socket_data(channel_ref, socket_id)
  end

  @spec delete_channel_data(binary()) :: :ok
  def delete_channel_data(channel_ref) do
    imp().delete_channel_data(channel_ref)
  end

  @spec get_channel_data(binary()) :: {:ok, Data.t()} | {:error, :not_found}
  def get_channel_data(channel_ref) do
    imp().get_channel_data(channel_ref)
  end

  @spec child_spec() :: [Supervisor.child_spec()] | []
  def child_spec do
    Application.put_env(
      :channel_sender_ex,
      :persistence_module,
      resolve_module(enabled?(), get_type())
    )

    imp().child_spec()
  end

  defp imp do
    case Application.get_env(:channel_sender_ex, :persistence_module) do
      nil -> NoopChannelPersistence
      module -> module
    end
  end

  defp resolve_module(_enabled? = false, _type), do: resolve_module(:noop)
  defp resolve_module(_enabled? = true, type), do: resolve_module(type)
  defp resolve_module(:redis), do: RedisChannelPersistence
  defp resolve_module(:noop), do: NoopChannelPersistence

  defp enabled? do
    Application.get_env(:channel_sender_ex, :persistence, [])
    |> Keyword.get(:enabled, false)
  end

  defp get_type do
    Application.get_env(:channel_sender_ex, :persistence, [])
    |> Keyword.get(:type, :noop)
  end
end
