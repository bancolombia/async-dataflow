defmodule BridgeCore.CachingProvider do
  @moduledoc """
  Behaviour definition for caching repository
  """

  @type key() :: String.t()
  @type value() :: any()

  @callback get(key()) :: {:ok, result :: term} | {:miss, reason :: term, value :: any()}
  @callback put(key(), value()) :: {:ok, value :: any()}
end
