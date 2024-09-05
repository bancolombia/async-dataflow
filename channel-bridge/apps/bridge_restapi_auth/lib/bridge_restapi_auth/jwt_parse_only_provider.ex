defmodule BridgeRestapiAuth.JwtParseOnlyProvider do
  @behaviour BridgeRestapiAuth.Provider

  @moduledoc """
  This Auth Provider behaviour implementation ONLY decodes and parses the JWT Token json.
  IMPORTANT: No validations are performed at all. Write your own auth stratey by implementing
  the BridgeRestapiAuth.Provider behaviour.
  """

  require Logger

  @type all_headers() :: map()
  @type reason() :: String.t()

  @doc """
  Parses token without any validation
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
    case credential do
      e when e in [nil, ""] ->
        {:error, :nocreds}

      _ ->
        {:ok,
        read_token(credential)
        |> Map.delete(:bearer_token)
        |> Map.delete(:head)
        |> Map.get(:claims)}
    end

  end

  defp peek_data({:error, reason}) do
    {:error, reason}
  end

  defp read_token(jwt) do
    {:ok, claims} = Joken.peek_claims(jwt)
    {:ok, head} = Joken.peek_header(jwt)

    %{
      bearer_token: jwt,
      claims: claims,
      head: head
    }
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      %{
        bearer_token: jwt,
        claims: nil,
        head: nil
      }
  end

end
