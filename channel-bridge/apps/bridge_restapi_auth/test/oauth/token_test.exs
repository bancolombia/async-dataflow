defmodule BridgeRestapiAuth.Oauth.TokenTest do
  use ExUnit.Case

  alias BridgeRestapiAuth.Oauth.Token

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

  test "should build configuration" do
    config = Token.token_config()
    assert Map.has_key?(config, "iss") == true
  end

  test "should pass issuer validation fn" do
    assert Token.issued_by_domain?("issuer1") == false
    assert Token.issued_by_domain?("some.issuer") == true
  end

  test "should pass audience validation fn" do
    assert Token.has_custom_api_audience?("audience1") == false
    assert Token.has_custom_api_audience?("aud2") == true
  end

end
