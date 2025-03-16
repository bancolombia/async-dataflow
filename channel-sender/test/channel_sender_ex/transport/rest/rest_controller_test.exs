defmodule ChannelSenderEx.Transport.Rest.RestControllerTest do
  use ExUnit.Case
  use Plug.Test
  import Mock

  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
  alias ChannelSenderEx.Transport.Rest.RestController
  alias ChannelSenderEx.Core.ChannelWorker
  alias ChannelSenderEx.Core.HeadlessChannelOperations

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

    with_mocks([
      {ChannelAuthenticator, [], [create_channel_credentials: fn(_, _) -> {"xxxx", "yyyy"} end]},
      {ChannelWorker, [], [save_channel: fn(_, _) -> :ok end]},
    ]) do
      conn = conn(:post, "/ext/channel/create", body)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-meta-foo", "bar")

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

  test "Should not create channel on bad request due to missing fields" do
    body = Jason.encode!(%{application_ref: "some_application", user_ref: nil})

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

    with_mock ChannelWorker, [route_message: fn(_) -> :ok end] do
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

  test "Should fail on invalid body due to invalid values" do
    body =
      Jason.encode!(%{
        channel_ref: nil,
        message_id: "message_id",
        correlation_id: "correlation_id",
        message_data: "message_data",
        event_name: "event_name"
      })

    conn = conn(:post, "/ext/channel/deliver_message", body)
      |> put_req_header("content-type", "application/json")

    conn = RestController.call(conn, @options)

    assert conn.status == 400

    assert %{"error" => "Invalid request" <> _rest} = Jason.decode!(conn.resp_body)
  end

  test "Should be able to call for close channel" do
    with_mocks([
      {ChannelWorker, [], [delete_channel: fn(_) -> :ok end]}
    ]) do

      conn2 = conn(:delete, "/ext/channel?channel_ref=xxxx")
      |> put_req_header("accept", "application/json")

      conn2 = RestController.call(conn2, @options)

      assert conn2.status == 202

      assert %{"result" => "Ok"} =
               Jason.decode!(conn2.resp_body)
    end
  end

  test "Should be able to handle invalid requesr for close channel" do
    with_mocks([
      {ChannelWorker, [], [delete_channel: fn(_) -> :noproc end]}
    ]) do

      conn2 = conn(:delete, "/ext/channel")
      |> put_req_header("accept", "application/json")

      conn2 = RestController.call(conn2, @options)

      assert conn2.status == 400

      assert %{"error" => "Invalid request", "request" => %{}} =
               Jason.decode!(conn2.resp_body)

    end
  end

  test "Should call connected from gateway" do

    with_mocks([
      {HeadlessChannelOperations, [], [on_connect: fn(_ref, _socket) -> {:ok, "OK"} end]},
    ]) do
      conn = conn(:post, "/ext/channel/gateway/connect", Jason.encode!(%{}))
      |> put_req_header("content-type", "application/json")
      |> put_req_header("channel", "xyz")
      |> put_req_header("connectionid", "abc")

      conn = RestController.call(conn, @options)

      assert conn.status == 200

      assert %{"message" => "OK"}=
               Jason.decode!(conn.resp_body)
    end

  end

  test "Should call connected from gateway and handle bad request" do

    with_mocks([
      {HeadlessChannelOperations, [], [on_connect: fn(_ref, _socket) -> {:error, "3008"} end]},
    ]) do
      conn = conn(:post, "/ext/channel/gateway/connect", Jason.encode!(%{}))
      |> put_req_header("content-type", "application/json")
      |> put_req_header("channel", "xyz")
      |> put_req_header("connectionid", "abc")

      conn = RestController.call(conn, @options)

      assert conn.status == 200

      assert %{"message" => "3008"}=
               Jason.decode!(conn.resp_body)
    end

  end

  test "Should call disconnected from gateway" do

    with_mocks([
      {HeadlessChannelOperations, [], [on_disconnect: fn(_connection_id) -> :ok end]},
    ]) do
      conn = conn(:post, "/ext/channel/gateway/disconnect", Jason.encode!(%{}))
      |> put_req_header("content-type", "application/json")
      |> put_req_header("connectionid", "abc")

      conn = RestController.call(conn, @options)

      assert conn.status == 200

      assert %{"message" => "Disconnect acknowledged"} =
               Jason.decode!(conn.resp_body)
    end

  end

  test "Should call auth message from gateway" do
    body = Jason.encode!(%{
      "action" => "sendMessage", "channel" => "xxx", "secret" => "foo.bar"
    })
    with_mocks([
      {HeadlessChannelOperations, [], [on_message: fn(_data, _connection_id) -> {:ok, "[\"\",\"AuthOK\", \"\", \"\"]"} end]},
    ]) do
      conn = conn(:post, "/ext/channel/gateway/message", body)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("connectionid", "abc")

      conn = RestController.call(conn, @options)

      assert conn.status == 200

      assert ["", "AuthOK", "", ""] =
               Jason.decode!(conn.resp_body)
    end
  end

  test "Should call auth message from gateway and handle unauthorized" do
    body = Jason.encode!(%{
      "action" => "sendMessage", "channel" => "xxx", "secret" => "foo.bar"
    })
    with_mocks([
      {HeadlessChannelOperations, [], [on_message: fn(_data, _connection_id) ->
        {:unauthorized, "[\"\",\"AuthFailed\", \"\", \"\"]"} end]},
    ]) do
      conn = conn(:post, "/ext/channel/gateway/message", body)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("connectionid", "abc")

      conn = RestController.call(conn, @options)

      assert conn.status == 401

      assert ["", "AuthFailed", "", ""] =
               Jason.decode!(conn.resp_body)
    end
  end

  test "Should call ack message from gateway" do
    body = Jason.encode!(%{
      "action" => "sendMessage", "channel" => "xxx", "ack_message_id" => "foo.bar"
    })
    with_mocks([
      {HeadlessChannelOperations, [], [on_message: fn(_data, _connection_id) ->
        {:ok, "[\"\",\"AckOK\", \"\", \"\"]"} end]},
    ]) do
      conn = conn(:post, "/ext/channel/gateway/message", body)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("connectionid", "abc")

      conn = RestController.call(conn, @options)

      assert conn.status == 200

      assert ["", "AckOK", "", ""] =
               Jason.decode!(conn.resp_body)
    end
  end

  test "Should call ack message from gateway and handle error" do
    body = Jason.encode!(%{
      "action" => "sendMessage", "channel" => "xxx", "ack_message_id" => "foo.bar"
    })
    with_mocks([
      {HeadlessChannelOperations, [], [on_message: fn(_data, _connection_id) ->
        raise ("Dummy Error")
      end]},
    ]) do
      conn = conn(:post, "/ext/channel/gateway/message", body)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("connectionid", "abc")

      conn = RestController.call(conn, @options)

      assert conn.status == 200

      assert ["", "Error", "", ""] =
               Jason.decode!(conn.resp_body)
    end
  end

end
