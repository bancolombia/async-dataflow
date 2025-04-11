defmodule ChannelSenderEx.Persistence.ChannelPersistence do
  @moduledoc """
  This module is responsible for persisting the channel data.
  """
  alias ChannelSenderEx.Persistence.NoopChannelPersistence
  alias ChannelSenderEx.Persistence.RedisChannelPersistence
  alias ChannelSenderEx.Persistence.RedisChannelPersistenceSync

  @behaviour ChannelSenderEx.Persistence.ChannelPersistenceBehavior

  @spec save_channel(binary(), binary()) :: :ok
  def save_channel(channel, socket) do
    imp().save_channel(channel, socket)
  end

  @spec save_socket(binary(), binary()) :: :ok
  def save_socket(channel_ref, socket_id) do
    imp().save_socket(channel_ref, socket_id)
  end

  @spec save_message(binary(), binary(), any()) :: :ok
  def save_message(channel_ref, message_id, message) do
    imp().save_message(channel_ref, message_id, message)
  end

  @spec delete_channel(binary(), binary()) :: :ok
  def delete_channel(channel_ref, socket \\ "") do
    imp().delete_channel(channel_ref, socket)
  end

  @spec delete_socket(binary(), binary()) :: :ok
  def delete_socket(socket, channel_ref \\ "") do
    imp().delete_socket(socket, channel_ref)
  end

  @spec delete_message(binary(), binary()) :: :ok
  def delete_message(channel_ref, message_id) do
    imp().delete_message(channel_ref, message_id)
  end

  @spec ack_message(binary(), binary()) :: :ok
  def ack_message(socket_ref, message_id) do
    imp().ack_message(socket_ref, message_id)
  end

  @spec get_channel(binary()) :: {:ok, String.t()} | {:error, :not_found}
  def get_channel(channel_ref) do
    imp().get_channel(channel_ref)
  end

  @spec get_socket(binary()) :: {:ok, String.t()} | {:error, :not_found}
  def get_socket(socket) do
    imp().get_socket(socket)
  end

  @spec get_message(binary(), binary()) :: {:ok, any()} | {:error, :not_found}
  def get_message(message_id, channel_ref \\ "") do
    imp().get_message(message_id, channel_ref)
  end

  @spec get_messages(binary()) :: {:ok, any()} | {:error, :not_found}
  def get_messages(channel_ref) do
    imp().get_messages(channel_ref)
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

  def health do
    imp().health()
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
  defp resolve_module(:redis_sync), do: RedisChannelPersistenceSync
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
