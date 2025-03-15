defmodule ChannelSenderEx.Persistence.NoopChannelPersistence do
  @moduledoc false
  @behaviour ChannelSenderEx.Persistence.ChannelPersistenceBehavior

  @impl true
  @spec save_channel(String.t(), String.t()) :: :ok
  def save_channel(_channel_ref, _socket), do: :ok

  @impl true
  @spec save_socket(String.t(), String.t()) :: :ok
  def save_socket(_channel_ref, _socket_id), do: :ok

  @impl true
  @spec get_socket(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get_socket(_socket), do: {:error, :not_found}

  @impl true
  @spec delete_socket(String.t(), String.t()) :: :ok
  def delete_socket(_socket, _channel), do: :ok

  @impl true
  @spec delete_channel(String.t(), String.t()) :: :ok
  def delete_channel(_channel_ref, _socket), do: :ok

  @impl true
  @spec get_channel(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get_channel(_channel_ref), do: {:error, :not_found}

  @impl true
  @spec delete_message(String.t()) :: :ok
  def delete_message(_message_id), do: :ok

  @impl true
  @spec save_message(String.t(), any()) :: :ok
  def save_message(_message_id, _message), do: :ok

  @impl true
  @spec get_message(String.t(), String.t()) :: {:ok, list()}
  def get_message(_message_id, _channel_ref), do: {:ok, []}

  @impl true
  @spec child_spec :: [Supervisor.child_spec()] | []
  def child_spec, do: []
end
