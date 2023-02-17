defmodule ChannelBridgeEx.Entrypoint.Rest.AuthPlugTest do
  use ExUnit.Case
  use Plug.Test
  import Mock

  alias ChannelBridgeEx.Entrypoint.Rest.AuthPlug
  alias ChannelBridgeEx.Entrypoint.Rest.AuthPlug.NoCredentialsError

  @moduletag :capture_log

  test "Should auth request" do
    body = %{}

    body =
      body
      |> Jason.encode!()

    conn =
      conn(:post, "/ext/channel", body)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer ey.a.c")

    with_mocks([
      {ChannelBridgeEx.Core.Auth.JwtParseOnly, [],
       [
         validate_credentials: fn _token ->
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

  test "Should fail auth request - no creds" do
    body = %{}

    body =
      body
      |> Jason.encode!()

    conn =
      conn(:post, "/ext/channel", body)
      |> put_req_header("content-type", "application/json")

    assert_raise NoCredentialsError, fn ->
      AuthPlug.call(conn, nil)
    end
  end

  test "Should options" do
    assert AuthPlug.init([]) == []
  end
end
