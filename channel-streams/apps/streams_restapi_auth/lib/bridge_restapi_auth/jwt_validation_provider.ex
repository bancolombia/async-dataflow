defmodule StreamsRestapiAuth.JwtValidationProvider do
  @behaviour StreamsRestapiAuth.Provider

  @moduledoc """
  This is a simple StreamsRestapiAuth.Provider that validates a JWT bearer token present in header
  as defined if StreamsRestapiAuth.Oauth.Config module.
  """

  alias StreamsRestapiAuth.Oauth.Token
  require Logger

  @type all_headers() :: map()
  @type body() :: map()
  @type reason() :: String.t()

  @spec validate_credentials(map()) ::
          {:error, :forbidden | :nocreds} | {:ok, %{optional(binary()) => any()}}
  @doc """
  Parses and validates token
  """
  @impl true
  def validate_credentials(all_headers) do
    fetch_auth_header(all_headers)
    |> validate_signature
  end

  defp fetch_auth_header(all_headers) do
    case Map.fetch(all_headers, "authorization") do
      {:ok, header_value} ->
        if header_value == "" do
          Logger.error("'Authorization' header is empty.")
          {:error, :nocreds}
        else
          {:ok, header_value |> String.split() |> List.last()}
        end

      :error ->
        Logger.error("'Authorization' header missing.")
        {:error, :nocreds}
    end
  end

  defp validate_signature({:ok, jwt}) do
    case Token.verify_and_validate(jwt) do
      {:ok, _credentials} = v ->
        v

      {:error, reason} ->
        Logger.error("Error validating token. #{inspect(reason)}")
        {:error, :forbidden}
    end
  end

  defp validate_signature({:error, _reason} = e), do: e
end
