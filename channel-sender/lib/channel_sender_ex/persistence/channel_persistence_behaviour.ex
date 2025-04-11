defmodule ChannelSenderEx.Persistence.ChannelPersistenceBehavior do
  @moduledoc false
  @callback save_channel(binary(), binary()) :: :ok
  @callback get_channel(binary()) :: {:ok, binary()} | {:error, :not_found}
  @callback delete_channel(binary(), binary()) :: :ok

  @callback save_socket(binary(), binary()) :: :ok
  @callback get_socket(binary()) :: {:ok, binary()} | {:error, :not_found}
  @callback delete_socket(binary(), binary()) :: :ok

  @callback save_message(binary(), binary(), any()) :: :ok
  @callback get_message(binary(), any()) :: {:ok, list()} | {:error, :not_found}
  @callback get_messages(binary()) :: {:ok, list()} | {:error, :not_found}
  @callback delete_message(binary(), binary()) :: :ok
  @callback ack_message(binary(), binary()) :: :ok

  @callback child_spec() :: [Supervisor.child_spec()] | []

  @callback health() :: :ok | {:error, any()}
end
