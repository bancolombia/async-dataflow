defmodule BridgeCore.SecretProvider do
  @moduledoc """
  Behaviour definition for a secrets repository
  """

  @type key() :: String.t()
  @type opts() :: Keyword.t()

  @callback get_secret(key(), opts()) :: {:ok, any()} | {:error, reason :: term}
end
