defmodule BridgeRestapiAuth.ApplicationTest do
  use ExUnit.Case, async: true

  import Mock

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

  test "Should test start app" do
    with_mocks([
      {BridgeRestapiAuth.Oauth.Strategy, [], []}
    ]) do
      config = []

      assert {:ok, _pid} = BridgeRestapiAuth.Application.start(:normal, [config])
    end
  end

  test "Should test build childspec" do
      assert {BridgeRestapiAuth.Oauth.Strategy, [first_fetch_sync: true, explicit_alg: "RS256"]}
       == BridgeRestapiAuth.Application.build_child_spec([])
  end

end
