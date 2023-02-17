defmodule ChannelBridgeEx.Entrypoint.Rest.HeaderTest do
  use ExUnit.Case
  use Plug.Test

  alias ChannelBridgeEx.Entrypoint.Rest.Header

  @moduletag :capture_log

  test "Should find header" do
    conn =
      conn(:post, "/ext/channel", %{})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer ey.a.c")
      |> put_req_header("session-tracker", "xxxx")

    assert {:ok, "xxxx"} == Header.get_header(conn, "session-tracker")
    assert {:error, :notfound} == Header.get_header(conn, "x-some-header")
    assert {:ok, "ey.a.c"} == Header.get_auth_header(conn)

    assert {:ok,
            %{
              "authorization" => "Bearer ey.a.c",
              "content-type" => "application/json",
              "session-tracker" => "xxxx"
            }} == Header.all_headers(conn)
  end

  test "Should not find header" do
    conn =
      conn(:post, "/ext/channel", %{})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("session-tracker", "xxxx")

    assert {:error, :nocreds} == Header.get_auth_header(conn)
  end
end
