defmodule StreamsApi.Rest.HeaderTest do
  use ExUnit.Case
  use Plug.Test

  alias StreamsApi.Rest.Header

  @moduletag :capture_log

  test "Should extract headers" do
    conn =
      conn(:post, "/ext/channel", %{})
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer ey.a.c")
      |> put_req_header("session-tracker", "xxxx")

    assert {:ok,
            %{
              "authorization" => "Bearer ey.a.c",
              "content-type" => "application/json",
              "session-tracker" => "xxxx"
            }} == Header.all_headers(conn)
  end

end
