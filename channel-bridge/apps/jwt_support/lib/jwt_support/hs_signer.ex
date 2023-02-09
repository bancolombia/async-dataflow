defmodule JwtSupport.HsSigner do
  @moduledoc """
  Builds a JOSE.JWK HS Signer from a symetric key stored in KMS.
  """

  alias JwtSupport.{SignerError, KmsHelper}

  @type opts() :: Map.t()
  @type signer() :: JOSE.JWK.t()

  @doc """
  Builds a JOSE.JWK HS Signer from an encripted symetric key.
  The key has to be decrypted with a symmetric key stored in KMS.
  """
  @spec build(opts()) :: signer()
  def build(opts) do
    opts.key
    |> decrypt
    |> build_jwk
  end

  defp decrypt(key) do
    case KmsHelper.decrypt(key) do
      :error ->
        raise SignerError, message: "Error decrypting security key"

      decrypted_value ->
        # base64 decode
        decrypted_value |> Base.decode64!()
    end
  end

  defp build_jwk(value) when is_binary(value) do
    JOSE.JWK.from_oct(value)
  end
end
