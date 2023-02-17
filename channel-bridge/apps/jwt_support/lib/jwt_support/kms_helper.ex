defmodule JwtSupport.KmsHelper do
  @moduledoc """
  KMS client
  """
  alias ExAws.KMS

  require Logger

  @doc """
  Send a decryption request to KMS
  """
  def decrypt(data) do
    KMS.decrypt(data)
    |> ExAws.request()
    |> process_decrypt_response
  end

  defp process_decrypt_response({:ok, decrypted}) do
    decrypted["Plaintext"]
  end

  defp process_decrypt_response({:error, reason}) do
    Logger.error("Could not decrypt data, reason: #{inspect(reason)}")
    :error
  end
end
