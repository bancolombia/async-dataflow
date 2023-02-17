defmodule ChannelBridgeEx.Core.Auth.PassthroughAuth do
  @behaviour ChannelBridgeEx.Core.Auth.AuthProvider

  @moduledoc """
  The AuthProvider behaviour applies an authentication strategy prior to invoking
  senders api rest endpoint to register a channel.

  In this implementation no authentication its performed at all.

  Write your own auth stratey by implementing the AuthProvider behaviour.
  """

  @doc """
  Performs no validation at all, and returns an empty Map since no JWT parsing nor validation is performed.
  """
  @impl true
  def validate_credentials(_all_headers) do
    {:ok, %{}}
  end
end
