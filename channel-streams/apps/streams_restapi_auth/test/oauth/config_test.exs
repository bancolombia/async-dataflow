defmodule StreamsRestapiAuth.Oauth.ConfigTest do
  use ExUnit.Case

  alias StreamsRestapiAuth.Oauth.Config

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

  test "should get configured issuers data" do
    assert Config.iss() == ["iss1", "some.issuer"]
  end

  test "should get configured audiences data" do
    assert Config.aud() == ["aud1", "aud2"]
  end

  test "should get configured jwks uri" do
    assert Config.jwks_url() == "https://someprovider.com/keys"
  end

end
