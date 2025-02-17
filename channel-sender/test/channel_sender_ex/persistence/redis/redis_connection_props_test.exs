defmodule ChannelSenderEx.Persistence.RedisConnectionPropsTest do
  use ExUnit.Case, async: false
  import Mock

  alias ChannelSenderEx.Persistence.RedisConnectionProps

  test "resolve_properties/1 with valid secret" do
    with_mock ExAws,
      request: fn _ ->
        {:ok, %{"SecretString" => "{\"host\": \"redis.example.com\", \"port\": \"6380\"}"}}
      end do
      cfg = [secret: "my_secret", host: "localhost", port: "6379"]
      props = RedisConnectionProps.resolve_properties(cfg)

      assert props[:host] == "redis.example.com"
      assert props[:port] == 6380
    end
  end

  test "resolve_properties/1 with no secret" do
    cfg = [host: "localhost", port: "6379"]
    props = RedisConnectionProps.resolve_properties(cfg)

    assert props[:host] == "localhost"
    assert props[:port] == 6379
  end

  test "resolve_properties/1 with secret error" do
    with_mock ExAws, request: fn _ -> {:error, :not_found} end do
      cfg = [secret: "invalid_secret"]

      assert_raise RuntimeError, "Failed to resolve redis properties", fn ->
        RedisConnectionProps.resolve_properties(cfg)
      end
    end
  end
end
