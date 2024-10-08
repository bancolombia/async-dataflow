defmodule StreamsRestapiAuth.PassthroughProvider do
  @behaviour StreamsRestapiAuth.Provider

  @moduledoc """
  This Auth Provider behaviour implementation performs NO AUTHENTICATION at all.
  IMPORTANT: Write your own auth stratey by implementing the StreamsRestapiAuth.Provider behaviour.
  """

  @doc """
  Performs no validations, and returns an empty Map since no JWT parsing nor validation is performed.
  """
  @impl true
  def validate_credentials(_all_headers) do
    {:ok, %{}}
  end

end
