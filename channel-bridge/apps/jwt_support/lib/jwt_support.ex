defmodule JwtSupport do
  @moduledoc """
  Module to support Token JWT Validation.
  """

  alias JwtSupport.HsSigner

  @type alg() :: String.t()
  @type token() :: String.t()
  @type opts() :: Map.t()
  @type signer() :: any()
  @type claims() :: Map.t()

  @doc """
  Validates Token signature and return claims if validation is successful.
  Token header should have the following claims:
  - alg : the algorithm used to encrypt the key.
  - kid : the encrypted asymmetric key.
  """
  @spec validate(alg(), opts()) :: claims()
  def validate(token, opts \\ %{}) do
    token
    |> peek_data
    |> with_signer
    |> verify_signature
  end

  @doc """
  Builds a HS Signer or a RS Signer, depending on input data
  """
  @spec build_signer(alg(), opts()) :: signer()
  def build_signer(alg, opts \\ %{}) do
    case alg do
      "HS" <> _ ->
        HsSigner.build(opts)

      "RS" <> _ ->
        # TODO: support of an Asymetric signer.
        nil
    end
  end

  defp verify_signature(data) do
    if :os.system_time(:second) > data.claims["exp"] do
      {:error, :expired_token}
    else
      {result, _body, _signer} = JOSE.JWK.verify(data.bearer_token, data.signer)

      case result do
        true ->
          {:ok, data.claims}

        _ ->
          {:error, :invalid_token}
      end
    end
  end

  def peek_data(jwt) do
    %{
      bearer_token: jwt,
      claims: JOSE.JWT.peek_payload(jwt) |> Map.get(:fields),
      head: JOSE.JWS.peek_protected(jwt) |> Jason.decode!()
    }
  end

  defp with_signer(data) do
    Map.put(data, :signer, build_signer(data.head["alg"], %{key: data.claims["kid"]}))
  end

end
