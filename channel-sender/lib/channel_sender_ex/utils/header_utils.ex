defmodule ChannelSenderEx.Utils.HeaderUtils do
  @moduledoc """
  This module provides utility functions for handling headers.
  """
  @metadata_headers_max 3
  @metadata_headers_prefix "x-meta-"

  def get_metadata_headers(conn) do
    # collect metadata from headers, up to 3 metadata fields
      conn.req_headers
      |> Enum.filter(fn {key, _} -> String.starts_with?(key, @metadata_headers_prefix) end)
      |> Enum.map(fn {key, value} ->
        {String.replace(key, @metadata_headers_prefix, ""), String.slice(value, 0, 50)}
      end)
      |> Enum.take(@metadata_headers_max)
  end
end
