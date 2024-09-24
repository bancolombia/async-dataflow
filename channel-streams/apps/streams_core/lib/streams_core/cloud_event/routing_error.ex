defmodule StreamsCore.CloudEvent.RoutingError do
  @moduledoc """
  Error raised when no routing throught ADF channel sender can be made
  """

  defexception message: ""
end
