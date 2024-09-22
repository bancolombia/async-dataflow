defmodule StreamsApi.Rest.AuthPlug do
  @moduledoc false

  alias StreamsApi.Rest.Header

  require Logger

  @type token() :: String.t()
  @type conn() :: Plug.Conn.t()

  defmodule AuthenticationError do
    @moduledoc """
    Error raised for authentication/autorization errors are detected
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

    with {:ok, all_headers} <- Header.all_headers(conn),
          {:ok, claims} <- auth_provider().validate_credentials(all_headers) do
      # auth was successful and claims are stored
      store_claims_private(claims, conn)
    else
      {:error, :nocreds} ->
        Logger.error("Credentials required for authentication")
        raise AuthenticationError, message: "Credentials required for authentication"
      {:error, :forbidden} ->
        Logger.error("Credentials error")
        raise AuthenticationError, message: "Invalid Credentials"
      {:error, :unauthorized} ->
        Logger.error("Not authorized")
        raise AuthenticationError, message: "Not authorized"
    end
  end

  defp auth_provider do
    case get_in(Application.get_env(:channel_streams, :config), [:streams, "channel_authenticator", "auth_module"]) do
      nil -> StreamsRestapiAuth.PassthroughProvider
      v -> v
    end
  end

  defp store_claims_private(claims, conn) do
    put_private(conn, :token_claims, claims)
  end
end
