defmodule BridgeApi.Rest.RestRouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias BridgeApi.Rest.ErrorResponse
  alias BridgeApi.Rest.RestHelper
  alias BridgeApi.Rest.RestRouter

  alias BridgeApi.Rest.AuthPlug.AuthenticationError

  @moduletag :capture_log

  import Mock

  # doctest RestRouter

  setup do

    token_claims = %{
      "claim1" => "abc321",
      "claim2" => "XwvMsZ",
      "exp" => 1_612_389_857_257,
      "scope" => "acme"
    }

    on_exit(fn ->
      Application.delete_env(:channel_bridge, :config)
    end)

    {:ok, init_args: %{claims: token_claims}}
  end

  @opts RestRouter.init([])

  test "Should create channel on request" do
    body = %{}

    with_mocks([
      {RestHelper, [],
        [
        start_session: fn _request_data ->
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

  test "Should not create channel - no data for channel alias" do
    body = %{}

    with_mocks([
      {RestHelper, [],
        [
          start_session: fn _data ->
            {%{
              "errors" => [
                ErrorResponse.new("", "", "ADF00102", "invalid alias parameter", "")
              ]
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
      body = Jason.decode!(conn.resp_body)
      assert body == %{"errors" => [%{"code" => "ADF00102", "domain" => "", "message" => "invalid alias parameter", "reason" => "", "type" => ""}]}
    end
  end

  test "Should not create channel - missing credentials for JwtParseOnly plug" do
    body = %{}

    conn =
      conn(:post, "/ext/channel", body)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("sub", "foo")
      # note there is no authorization header present

    cfg = %{
      bridge: %{
        "channel_authenticator" => %{"auth_module" => Elixir.BridgeRestapiAuth.JwtParseOnlyProvider},
      }
    }
    Application.put_env(:channel_bridge, :config, cfg)

    with_mocks([
      {RestHelper, [],
        [start_session: fn _request_data ->
          {%{"result" => "ok"}, 200}
        end]}
    ]) do
      assert_raise AuthenticationError, fn ->
        RestRouter.call(conn, @opts)
      end
    end
  end

  test "Should delete channel" do
    with_mocks([
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
        |> put_req_header("sub", "xxxx")

      conn = RestRouter.call(conn, @opts)

      assert conn.status == 200
      assert conn.resp_body == "{\"result\":\"ok\"}"
    end
  end

  test "Should obtain OK response from liveness probe" do
    with_mocks([
      {BridgeRestapiAuth.JwtParseOnlyProvider, [],
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
      {BridgeRestapiAuth.JwtParseOnlyProvider, [],
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
      {BridgeRestapiAuth.JwtParseOnlyProvider, [],
        [validate_credentials: fn _token -> {:ok, %{}} end]}
    ]) do
      conn = conn(:get, "/hello")
      conn = RestRouter.call(conn, @opts)

      assert conn.status == 404

      assert conn.resp_body == "Resource not found"
    end
  end

end
