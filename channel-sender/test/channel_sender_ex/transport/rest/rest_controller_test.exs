defmodule ChannelSenderEx.Transport.Rest.RestControllerTest do
  use ExUnit.Case
  use Plug.Test
  import Mock

  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
  alias ChannelSenderEx.Core.PubSub.PubSubCore
  alias ChannelSenderEx.Transport.Rest.RestController

  @moduletag :capture_log
  @options RestController.init([])

  doctest RestController

  test "Should consume health endpoint" do
    conn = conn(:get, "/health")
    |> put_req_header("content-type", "application/json")
    conn = RestController.call(conn, @options)
    assert conn.status == 200
  end

  test "Should handle unexistent route" do
    conn = conn(:get, "/some_unexistent_route")
    |> put_req_header("content-type", "application/json")
    conn = RestController.call(conn, @options)
    assert conn.status == 404
  end

  test "Should create channel on request" do
    body = Jason.encode!(%{application_ref: "some_application", user_ref: "user_ref_00117ALM"})

    with_mock ChannelAuthenticator, [create_channel: fn(_, _) -> {"xxxx", "yyyy"} end] do

      conn = conn(:post, "/ext/channel/create", body)
      |> put_req_header("content-type", "application/json")

      conn = RestController.call(conn, @options)

      assert conn.status == 200

      assert %{"channel_ref" => "xxxx", "channel_secret" => "yyyy"} =
               Jason.decode!(conn.resp_body)
    end

  end

  test "Should not create channel on bad request" do
    body = %{}

    conn = conn(:post, "/ext/channel/create", body)
    |> put_req_header("content-type", "application/json")

    conn = RestController.call(conn, @options)

    assert conn.status == 400

  end

  test "Should send message on request" do

    body =
      Jason.encode!(%{
        channel_ref: "010101010101",
        message_id: "message_id",
        correlation_id: "correlation_id",
        message_data: "message_data",
        event_name: "event_name"
      })

    with_mock PubSubCore, [deliver_to_channel: fn(_, _) -> :ok end] do
      conn = conn(:post, "/ext/channel/deliver_message", body)
        |> put_req_header("content-type", "application/json")

      conn = RestController.call(conn, @options)

      assert conn.status == 202

      assert %{"result" => "Ok"} = Jason.decode!(conn.resp_body)

      assert Enum.member?(conn.resp_headers, {"content-type", "application/json"})
    end

  end

  test "Should fail on invalid body" do
    body =
      Jason.encode!(%{
        channel_ref: "channel_ref",
        message_id: "message_id"
      })

    conn = conn(:post, "/ext/channel/deliver_message", body)
      |> put_req_header("content-type", "application/json")

    conn = RestController.call(conn, @options)

    assert conn.status == 400

    assert %{"error" => "Invalid request" <> _rest} = Jason.decode!(conn.resp_body)

  end

end
