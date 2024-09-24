defmodule StreamsRestapiAuth.Provider do
  @moduledoc """
  Behaviour definition for the authentication strategy
  """

  @type all_headers :: map()
  @type credentials() :: map()
  @type reason() :: any()

  @doc """
  Validates user credentials
  """
  @callback validate_credentials(all_headers()) :: {:error, reason()} | {:ok, credentials()}

end
