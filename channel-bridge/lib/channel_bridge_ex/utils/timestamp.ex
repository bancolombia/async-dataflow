defmodule ChannelBridgeEx.Utils.Timestamp do
  @moduledoc """
  Utilities for handling timestamps
  """

  @doc """
  obtains current timestamp in seconds
  """
  def now do
    DateTime.utc_now() |> DateTime.to_unix(:second)
  end

  @doc """
  Compares if provided 'timestamp' is before current date/time
  """
  def has_elapsed(timestamp) do
    timestamp < now()
  end
end
