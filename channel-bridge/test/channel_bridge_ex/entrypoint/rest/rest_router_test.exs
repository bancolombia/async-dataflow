defmodule ChannelBridgeEx.Entrypoint.Rest.RestRouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias ChannelBridgeEx.Entrypoint.Rest.RestRouter
  alias ChannelBridgeEx.Entrypoint.Rest.RestHelper
  alias ChannelBridgeEx.Entrypoint.Rest.AuthPlug.NoCredentialsError

  @moduletag :capture_log

  import Mock

  # doctest RestRouter

  setup_all do
    token_claims = %{
      "application-id" => "abc321",
      "authorizationCode" => "XwvMsZ",
      "channel" => "BLM",
      "documentNumber" => "1989637100",
      "documentType" => "CC",
      "exp" => 1_612_389_857_257,
      "kid" =>
        "S2Fybjphd3M6a21zOnVzLWVhc3QtMTowMDAwMDAwMDAwMDA6a2V5LzI3MmFiODJkLTA1YjYtNGNmYy04ZjlhLTVjZTNlZDU0MjAyZAAAAAAEj3SnhcQeBKy172uCWtuJF5GPpvc3xfzrS+RcBhnXtw+Km4CCBDKc2psu++LGhvphOmGJByu6zCHQmFI=",
      "scope" => "BLM"
    }

    {:ok, init_args: %{claims: token_claims}}
  end

  @opts RestRouter.init([])

  test "Should create channel on request", %{init_args: init_args} do
    body = %{}

    with_mocks([
      {ChannelBridgeEx.Core.Auth.JwtParseOnly, [],
       [validate_credentials: fn _headers -> {:ok, init_args.claims} end]},
      {RestHelper, [],
       [
         start_channel: fn _data ->
           {%{
              "channel_alias" => "a",
              "channel_ref" => "b",
              "channel_secret" => "c"
            }, 200}
         end
       ]}
    ]) do
      conn =
        conn(:post, "/ext/channel", body)
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", "Bearer ey.a.c")
        |> put_req_header("session-tracker", "xxxx")

      conn = RestRouter.call(conn, @opts)

      assert conn.status == 200

      assert conn.resp_body == "{\"channel_alias\":\"a\",\"channel_ref\":\"b\",\"channel_secret\":\"c\"}"
    end
  end

  test "Should not create channel - already registered", %{init_args: init_args} do
    body = %{}

    with_mocks([
      {ChannelBridgeEx.Core.Auth.JwtParseOnly, [],
       [validate_credentials: fn _token -> {:ok, init_args.claims} end]},
      {RestHelper, [],
       [
         start_channel: fn _data ->
           {%{
              error: "channel already registered"
            }, 400}
         end
       ]}
    ]) do
      conn =
        conn(:post, "/ext/channel", body)
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", "Bearer ey.a.c")
        |> put_req_header("session-tracker", "x2")

      conn = RestRouter.call(conn, @opts)

      assert conn.status == 400
      assert conn.resp_body == "{\"error\":\"channel already registered\"}"
    end
  end

  test "Should not create channel - no data for channel alias", %{init_args: init_args} do
    body = %{}

    with_mocks([
      {ChannelBridgeEx.Core.Auth.JwtParseOnly, [],
       [validate_credentials: fn _token -> {:ok, init_args.claims} end]},
      {RestHelper, [],
       [
         start_channel: fn _data ->
           {%{
              error: "Alias error"
            }, 400}
         end
       ]}
    ]) do
      conn =
        conn(:post, "/ext/channel", body)
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", "Bearer ey.a.c")

      conn = RestRouter.call(conn, @opts)

      assert conn.status == 400
      assert conn.resp_body == "{\"error\":\"Alias error\"}"
    end
  end

  test "Should not create channel - invalid credentials for parsing" do
    body = %{}

    conn =
      conn(:post, "/ext/channel", body)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer ey.a.c")
      |> put_req_header("session-tracker", "x3")

    with_mocks([
      {ChannelBridgeEx.Core.Auth.JwtParseOnly, [],
       [validate_credentials: fn _token -> {:error, :nocreds} end]}
    ]) do
      assert_raise NoCredentialsError, fn ->
        RestRouter.call(conn, @opts)
      end
    end
  end

  test "Should delete channel", %{init_args: init_args} do
    with_mocks([
      {ChannelBridgeEx.Core.Auth.JwtParseOnly, [],
       [validate_credentials: fn _token -> {:ok, init_args.claims} end]},
      {RestHelper, [],
       [
         close_channel: fn _data ->
           {%{"result" => "ok"}, 200}
         end
       ]}
    ]) do
      conn =
        conn(:delete, "/ext/channel")
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", "Bearer ey.a.c")
        |> put_req_header("session-tracker", "xxxx")

      conn = RestRouter.call(conn, @opts)

      assert conn.status == 200
      assert conn.resp_body == "{\"result\":\"ok\"}"
    end
  end

  test "Should obtain OK response from liveness probe" do
    with_mocks([
      {ChannelBridgeEx.Core.Auth.JwtParseOnly, [],
       [validate_credentials: fn _token -> {:ok, %{}} end]}
    ]) do
      conn = conn(:get, "/liveness")
      conn = RestRouter.call(conn, @opts)

      assert conn.status == 200

      assert conn.resp_body == "OK"
    end
  end

  test "Should obtain OK response from readiness probe" do
    with_mocks([
      {ChannelBridgeEx.Core.Auth.JwtParseOnly, [],
       [validate_credentials: fn _token -> {:ok, %{}} end]}
    ]) do
      conn = conn(:get, "/readiness")
      conn = RestRouter.call(conn, @opts)

      assert conn.status == 200

      assert conn.resp_body == "OK"
    end
  end

  test "Should handle unknown path" do
    with_mocks([
      {ChannelBridgeEx.Core.Auth.JwtParseOnly, [],
       [validate_credentials: fn _token -> {:ok, %{}} end]}
    ]) do
      conn = conn(:get, "/hello")
      conn = RestRouter.call(conn, @opts)

      assert conn.status == 404

      assert conn.resp_body == "Resource not found"
    end
  end

end
