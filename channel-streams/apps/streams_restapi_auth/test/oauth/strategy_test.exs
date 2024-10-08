defmodule StreamsRestapiAuth.Oauth.StrategyTest do
  use ExUnit.Case

  alias StreamsRestapiAuth.Oauth.Strategy

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

  test "should build opts for strategy" do
    assert Strategy.init_opts([]) == [jwks_url: "https://someprovider.com/keys"]
  end

end
