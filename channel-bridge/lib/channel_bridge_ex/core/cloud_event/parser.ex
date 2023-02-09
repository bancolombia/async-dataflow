defmodule ChannelBridgeEx.Core.CloudEvent.Parser do
  @moduledoc """
  JSON parser for encoded cloud events.
  """

  @type t :: module

  @typedoc "JSON encoded CloudEvent."
  @type encoded_json :: String.t()

  @typedoc "Map CloudEvent."
  @type json :: Map.t()

  @doc """
  Parse a JSON encoded CloudEvent and performs validation against a json schema
  """
  @callback validate(json) :: t
end
