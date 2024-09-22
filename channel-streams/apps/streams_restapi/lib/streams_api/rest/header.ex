defmodule StreamsApi.Rest.Header do
  @moduledoc """
  Helper Function for extractig header values
  """

  @type headers_map :: map()
  @type conn :: %Plug.Conn{}

  @spec all_headers(conn()) :: {:ok, headers_map()}
  def all_headers(conn) do
    {:ok, Enum.into(conn.req_headers, %{})}
  end
end
