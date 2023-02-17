defmodule ChannelBridgeEx.Core.Auth.AuthProvider do
  @moduledoc """
  Behaviour definition for the authentication strategy
  """

  @type all_headers :: Map.t()
  @type reason() :: any()

  @doc """
  Validates user credentials
  """
  @callback validate_credentials(all_headers()) :: {:unauthorized, reason()} | {:ok, Map.t()}
end
