defmodule BridgeApi.Rest.AuthPlugTest do
  use ExUnit.Case
  use Plug.Test
  import Mock

  alias BridgeApi.Rest.AuthPlug
  alias BridgeApi.Rest.AuthPlug.AuthenticationError

  @moduletag :capture_log

  setup_all do
    cfg = %{
      bridge: %{
        "channel_authenticator" => %{
          "auth_module" => Elixir.BridgeRestapiAuth.JwtParseOnlyProvider
        }
      }
    }
    Application.put_env(:channel_bridge, :config, cfg)

    on_exit(fn ->
      Application.delete_env(:channel_bridge, :config)
    end)
  end

  test "Should process Auth implementation in request" do
    body = %{}

    body =
      body
      |> Jason.encode!()

    conn =
      conn(:post, "/ext/channel", body)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer ey.a.c")

    with_mocks([
      {BridgeRestapiAuth.JwtParseOnlyProvider, [],
       [
         validate_credentials: fn _headers ->
           {:ok,
            %{
              "application-id" => "abc321",
              "authorizationCode" => "XwvMsZ",
              "channel" => "BLM",
              "documentNumber" => "1989637100",
              "documentType" => "CC",
              "exp" => 1_612_389_857_257,
              "kid" =>
                "S2Fybjphd3M6a21zOnVzLWVhc3QtMTowMDAwMDAwMDAwMDA6a2V5LzI3MmFiODJkLTA1YjYtNGNmYy04ZjlhLTVjZTNlZDU0MjAyZAAAAAAEj3SnhcQeBKy172uCWtuJF5GPpvc3xfzrS+RcBhnXtw+Km4CCBDKc2psu++LGhvphOmGJByu6zCHQmFI=",
              "scope" => "BLM"
            }}
         end
       ]}
    ]) do
      conn = AuthPlug.call(conn, nil)
      assert conn.private[:token_claims] != nil
    end
  end

  test "Should handle fail auth in request - no creds" do

    body = %{}

    body =
      body
      |> Jason.encode!()

    conn =
      conn(:post, "/ext/channel", body)
      |> put_req_header("content-type", "application/json")

    with_mocks([
      {BridgeRestapiAuth.JwtParseOnlyProvider, [],
        [
          validate_credentials: fn _headers ->
            {:error, :nocreds}
          end
        ]}
    ]) do

      assert_raise AuthenticationError, fn ->
        AuthPlug.call(conn, nil)
      end

    end
  end

  test "Should handle fail auth in request - invalid credentials" do

    body = %{}

    body =
      body
      |> Jason.encode!()

    conn =
      conn(:post, "/ext/channel", body)
      |> put_req_header("content-type", "application/json")

    with_mocks([
      {BridgeRestapiAuth.JwtParseOnlyProvider, [],
        [
          validate_credentials: fn _headers ->
            {:error, :forbidden}
          end
        ]}
    ]) do

      assert_raise AuthenticationError, fn ->
        AuthPlug.call(conn, nil)
      end

    end
  end

  test "Should handle fail authz in request" do

    body = %{}

    body =
      body
      |> Jason.encode!()

    conn =
      conn(:post, "/ext/channel", body)
      |> put_req_header("content-type", "application/json")

    with_mocks([
      {BridgeRestapiAuth.JwtParseOnlyProvider, [],
        [
          validate_credentials: fn _headers ->
            {:error, :nocreds}
          end
        ]}
    ]) do

      assert_raise AuthenticationError, fn ->
        AuthPlug.call(conn, nil)
      end

    end
  end

  test "Should options" do
    assert AuthPlug.init([]) == []
  end
end
