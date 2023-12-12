defmodule BridgeApi.Rest.Header do
  @moduledoc """
  Helper Function for extractig header values
  """
  import Plug.Conn

  @type header_name :: String.t()
  @type header_value :: String.t()
  @type headers_map :: map()
  @type conn :: %Plug.Conn{}

  @spec get_header(conn(), header_name()) :: {:error, :notfound} | {:ok, header_value()}
  def get_header(conn, header_name) do
    case get_req_header(conn, header_name) do
      [] ->
        {:error, :notfound}

      [header] ->
        {:ok, header}
    end
  end

  @spec get_auth_header(conn()) :: {:error, :nocreds} | {:ok, header_value()}
  def get_auth_header(conn) do
    case get_header(conn, "authorization") do
      {:error, :notfound} -> {:error, :nocreds}
      {:ok, header} -> {:ok, header |> String.split() |> List.last()}
    end
  end

  @spec all_headers(conn()) :: {:ok, headers_map()}
  def all_headers(conn) do
    {:ok, Enum.into(conn.req_headers, %{})}
  end
end
