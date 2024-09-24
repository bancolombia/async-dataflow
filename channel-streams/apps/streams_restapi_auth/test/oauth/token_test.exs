defmodule StreamsRestapiAuth.Oauth.TokenTest do
  use ExUnit.Case

  alias StreamsRestapiAuth.Oauth.Token

  @moduletag :capture_log

  setup_all do
    cfg = %{
      streams: %{
        "channel_authenticator" => %{
          "auth_module" => Elixir.StreamsRestapiAuth.JwtValidationProvider,
          "config" => %{
            "jwks" => "https://someprovider.com/keys",
            "allowed_audiences" => ["aud1", "aud2"],
            "allowed_issuers" => ["iss1", "some.issuer"],
          }
        }
      }
    }
    Application.put_env(:channel_streams, :config, cfg)

    on_exit(fn ->
      Application.delete_env(:channel_streams, :config)
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
