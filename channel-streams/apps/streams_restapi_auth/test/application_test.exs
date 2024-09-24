defmodule StreamsRestapiAuth.ApplicationTest do
  use ExUnit.Case, async: true

  import Mock

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

  test "Should test start app" do
    with_mocks([
      {StreamsRestapiAuth.Oauth.Strategy, [], []}
    ]) do
      config = []

      assert {:ok, _pid} = StreamsRestapiAuth.Application.start(:normal, [config])
    end
  end

  test "Should test build childspec" do
      assert {StreamsRestapiAuth.Oauth.Strategy, [first_fetch_sync: true, explicit_alg: "RS256"]}
       == StreamsRestapiAuth.Application.build_child_spec([])
  end

end
