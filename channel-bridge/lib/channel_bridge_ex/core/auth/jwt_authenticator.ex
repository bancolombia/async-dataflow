defmodule ChannelBridgeEx.Core.Auth.JwtAuthenticator do
  @behaviour ChannelBridgeEx.Core.Auth.AuthProvider

  @moduledoc """
  Channel Authentication with JWT
  """
  require Logger

  @type all_headers() :: Map.t()
  @type reason() :: String.t()

  @doc """
  Validates user credentials (access token) obtained from an oauth2 authentication flow
  """
  @impl true
  def validate_credentials(all_headers) do
    auth_header = fetch_auth_header!(all_headers)

    case JwtSupport.validate(auth_header) do
      {:ok, claims} ->
        {:ok, claims}

      {:error, error_reason} ->
        Logger.error("Invalid token received: #{inspect(error_reason)}")
        {:unauthorized, "invalid token"}
    end
  end

  defp fetch_auth_header!(all_headers) do
    case Map.fetch(all_headers, "authorization") do
      {:ok, header_value} -> header_value |> String.split() |> List.last()
      {:error, _reason} -> ""
    end
  end
end
