defmodule BridgeRestapiAuth.JwtValidationProviderTest do
  use ExUnit.Case
  import Mock

  alias BridgeRestapiAuth.JwtValidationProvider

  @moduletag :capture_log

  setup_all do
    cfg = %{
      bridge: %{
        "channel_authenticator" => %{
          "auth_module" => Elixir.BridgeRestapiAuth.JwtValidationProvider,
          "config" => %{
            "jwks" => "https://someprovider.com/keys",
            "allowed_audiences" => ["aud1", "aud2"],
            "allowed_issuers" => ["iss1", "some.issuer"],
          }
        }
      }
    }
    Application.put_env(:channel_bridge, :config, cfg)

    on_exit(fn ->
      Application.delete_env(:channel_bridge, :config)
    end)
  end

  test "should validate header authentication" do

    # BridgeRestapiAuth.JwtValidationProvider.Token.MyJWKSStrategy.start_link(
    #   jwks_url: "https://login.microsoftonline.com/common/discovery/v2.0/keys",
    #   http_adapter: Tesla.Adapter.Hackney,
    #   first_fetch_sync: true
    # )

    # BridgeRestapiAuth.Oauth.Strategy.start_link([first_fetch_sync: true, explicit_alg: "RS256"])

    headers = %{
      "content-type" => "application/json",
      "authorization" => "Bearer ey...",
    }

    with_mocks([
     {BridgeRestapiAuth.Oauth.Token, [],
       [
        verify_and_validate: fn _token ->
           {:ok, %{"iat" => 1516239022, "iss" => "some.issuer",
            "aud" => "aud1", "name" => "John Doe", "sub" => "1234567890"}
           }
         end
       ]}
    ]) do
      {:ok, claims} = JwtValidationProvider.validate_credentials(headers)
      assert Map.has_key?(claims, "iss") == true
      assert Map.get(claims, "iss") == "some.issuer"
    end

  end

  test "should handle fail authentication" do

    headers = %{
      "content-type" => "application/json",
      "authorization" => "Bearer ey...",
    }

    with_mocks([
     {BridgeRestapiAuth.Oauth.Token, [],
       [
        verify_and_validate: fn _token ->
           {:error, [message: "Invalid token", claim: "exp", claim_val: 1716774434]}
         end
       ]}
    ]) do
      {:error, :forbidden} = JwtValidationProvider.validate_credentials(headers)
    end

  end

 test "should handle empty header authentication" do

   headers = %{
     "content-type" => "application/json",
     "authorization" => "",
     "session-tracker" => "xxxx"
   }

   assert JwtValidationProvider.validate_credentials(headers) == {:error, :nocreds}
 end

 test "should handle empty map headers" do
   headers = %{}
   assert JwtValidationProvider.validate_credentials(headers) == {:error, :nocreds}
 end



end
