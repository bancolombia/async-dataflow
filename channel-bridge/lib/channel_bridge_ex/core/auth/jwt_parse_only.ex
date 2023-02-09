defmodule ChannelBridgeEx.Core.Auth.JwtParseOnly do
  @behaviour ChannelBridgeEx.Core.Auth.AuthProvider

  @moduledoc """
  Channel Authentication - WARNING: Just parses the JWT, without any validation.
  """

  require Logger

  @type all_headers() :: Map.t()
  @type reason() :: String.t()

  @doc """
  Parses token without validation
  """
  @impl true
  def validate_credentials(all_headers) do
    fetch_auth_header(all_headers)
    |> peek_data
  end

  defp fetch_auth_header(all_headers) do
    case Map.fetch(all_headers, "authorization") do
      {:ok, header_value} ->
        {:ok, header_value |> String.split() |> List.last()}

      :error ->
        {:error, :nocreds}
    end
  end

  defp peek_data({:ok, credential}) do
    {:ok,
     JwtSupport.peek_data(credential)
     |> Map.delete(:bearer_token)
     |> Map.delete(:head)
     |> Map.get(:claims)}
  end

  defp peek_data({:error, reason}) do
    {:error, reason}
  end
end
