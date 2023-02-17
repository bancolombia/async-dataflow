defmodule ChannelBridgeEx.Entrypoint.Rest.AuthPlug do
  @moduledoc false

  alias ChannelBridgeEx.Entrypoint.Rest.Header

  require Logger

  @type token() :: String.t()
  @type conn() :: Plug.Conn.t()

  defmodule NoCredentialsError do
    @moduledoc """
    Error raised when no credentials are sent in request
    """

    defexception message: ""
  end

  import Plug.Conn

  def init(options), do: options

  @doc """
  Performs authentication. The concrete auth is implemented via @behaviour 'AuthProvider', and
  defined in configuration env property :channel_authenticator.
  """
  def call(conn, _opts) do

    auth_provider = Application.get_env(:channel_bridge_ex, :channel_authenticator, ChannelBridgeEx.Core.Auth.PassthroughAuth)

    with {:ok, all_headers} <- Header.all_headers(conn),
         {:ok, claims} <- auth_provider.validate_credentials(all_headers) do
      # auth was successful and claims are stored
      store_claims_private(claims, conn)
    else
      {:error, :nocreds} ->
        Logger.error("Credentials required for authentication")
        raise NoCredentialsError, message: "Credentials required for authentication"
    end
  end

  defp store_claims_private(claims, conn) do
    put_private(conn, :token_claims, claims)
  end
end
