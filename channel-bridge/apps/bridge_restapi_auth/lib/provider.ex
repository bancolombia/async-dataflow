defmodule BridgeRestapiAuth.Provider do
  @moduledoc """
  Behaviour definition for the authentication strategy
  """

  @type all_headers :: map()
  @type reason() :: any()

  @doc """
  Validates user credentials
  """
  @callback validate_credentials(all_headers()) :: {:unauthorized, reason()} | {:ok, map()}
end
