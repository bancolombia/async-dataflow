defmodule JwtSupportTest do
  use ExUnit.Case
  doctest JwtSupport

  import Mock

  @moduletag :capture_log

  # setup do
  #   token =
  #     "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhcHBsaWNhdGlvbi1pZCI6ImFiYzMyMSIsImF1dGhvcml6YXRpb25Db2RlIjoiNTA0ZGQyIiwiY2hhbm5lbCI6IkJMTSIsImRvY3VtZW50TnVtYmVyIjoiMTk4OTY3IiwiZG9jdW1lbnRUeXBlIjoiQ0MiLCJleHAiOjE2MTcwMzA1OTIsImtpZCI6IlMyRnlianBoZDNNNmEyMXpPblZ6TFdWaGMzUXRNVG93TURBd01EQXdNREF3TURBNmEyVjVMekkzTW1GaU9ESmtMVEExWWpZdE5HTm1ZeTA0WmpsaExUVmpaVE5sWkRVME1qQXlaQUFBQUFCOEFncytFUmllSE1JaHJzazBwNzRnNTVUZlUrakZFVTNkckNOTEdHTDlvWU9nZHJxREhNeFZtSWV3M1VsTXZqNGVzUVdmdnZUZUtuTUlrYk09Iiwic2NvcGUiOiJCTE0ifQ.v5hsJ_edImOjEM-HtOItncM2oQt81_tEM85Gte7KzLU"

  #   {:ok, init_args: %{token: token}}
  # end

  test "Should build signer HS256" do
    with_mocks([
      {JwtSupport.HsSigner, [],
       [
         build: fn _opts ->
           JOSE.JWK.from_oct("qwertyuiopasdfghjklzxcvbnm123456")
         end
       ]}
    ]) do
      signer = JwtSupport.build_signer("HS256", %{key: "abc"})
      assert signer != nil
    end
  end

  test "Should not build other type of signer" do
    signer = JwtSupport.build_signer("RS256", %{key: "abc"})
    assert signer == nil

    signer2 = JwtSupport.build_signer("RS256")
    assert signer2 == nil
  end

  test "Should validate token using HS256 signer" do

    jwk_hs256 = JOSE.JWK.generate_key({:oct, 16})
    jwt       = %{ "test" => true }
    signed_hs256 = JOSE.JWT.sign(jwk_hs256, %{ "alg" => "HS256" }, jwt) |> JOSE.JWS.compact |> elem(1)

    with_mocks([
      {JwtSupport.HsSigner, [],
       [
         build: fn _opts ->
          jwk_hs256
         end
       ]}
    ]) do
      validated = JwtSupport.validate(signed_hs256)
      assert validated == {:ok, jwt}
    end
  end

  test "Should fail validate token using HS256 signer" do

    jwk_hs256 = JOSE.JWK.generate_key({:oct, 16})
    jwt       = %{ "test" => true }
    signed_hs256 = JOSE.JWT.sign(jwk_hs256, %{ "alg" => "HS256" }, jwt) |> JOSE.JWS.compact |> elem(1)

    with_mocks([
      {JwtSupport.HsSigner, [],
       [
         build: fn _opts ->
          JOSE.JWK.generate_key({:oct, 16}) # different signer to force validation error
         end
       ]}
    ]) do
      validated = JwtSupport.validate(signed_hs256)
      assert validated == {:error, :invalid_token}
    end
  end
end
