defmodule ChannelSenderEx.Transport.Rest.RestControllerTest do
  use ExUnit.Case
  use Plug.Test
  import Mock

  alias ChannelSenderEx.Core.PubSub.PubSubCore
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
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

    with_mock ChannelAuthenticator, [create_channel: fn(_, _, _) -> {"xxxx", "yyyy"} end] do

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

    with_mock PubSubCore, [deliver_to_channel: fn(_, _) -> :ok end] do
      conn = conn(:post, "/ext/channel/deliver_message", body)
        |> put_req_header("content-type", "application/json")

      conn = RestController.call(conn, @options)

      assert conn.status == 202

      assert %{"result" => "Ok"} = Jason.decode!(conn.resp_body)

      assert Enum.member?(conn.resp_headers, {"content-type", "application/json"})
    end

  end

  test "Should send message to app channels" do

    body =
      Jason.encode!(%{
        app_ref: "app01",
        message_id: "message_id",
        correlation_id: "correlation_id",
        message_data: "message_data",
        event_name: "event_name"
      })

    with_mock PubSubCore, [deliver_to_app_channels: fn(_app_ref, _msg) ->
      %{accepted_waiting: 1, accepted_connected: 3}
     end] do
      conn = conn(:post, "/ext/channel/deliver_message", body)
        |> put_req_header("content-type", "application/json")

      conn = RestController.call(conn, @options)

      assert conn.status == 202

      assert %{"result" => "Ok"} = Jason.decode!(conn.resp_body)

      assert Enum.member?(conn.resp_headers, {"content-type", "application/json"})
    end
  end

  test "Should send message to users channels" do

    body =
      Jason.encode!(%{
        user_ref: "user01",
        message_id: "message_id",
        correlation_id: "correlation_id",
        message_data: "message_data",
        event_name: "event_name"
      })

    with_mock PubSubCore, [deliver_to_user_channels: fn(_user_ref, _msg) ->
      %{accepted_waiting: 0, accepted_connected: 2}
     end] do
      conn = conn(:post, "/ext/channel/deliver_message", body)
        |> put_req_header("content-type", "application/json")

      conn = RestController.call(conn, @options)

      assert conn.status == 202

      assert %{"result" => "Ok"} = Jason.decode!(conn.resp_body)

      assert Enum.member?(conn.resp_headers, {"content-type", "application/json"})
    end
  end

  test "Should send message batch of max messages allowed" do

    messages = Enum.map(1..10, fn i ->
      %{
        channel_ref: "channel_ref_#{i}",
        message_id: "message_#{i}",
        correlation_id: "correlation_id",
        message_data: "message_data",
        event_name: "event_name"
      }
    end) |> Enum.to_list()

    body =
      Jason.encode!(%{
        messages: messages
      })

    with_mock PubSubCore, [deliver_to_channel: fn(_channel_ref, _msg) ->
      :accepted_connected
     end] do
      conn = conn(:post, "/ext/channel/deliver_batch", body)
        |> put_req_header("content-type", "application/json")

      conn = RestController.call(conn, @options)

      assert conn.status == 202

      assert %{"result" => "Ok"} = Jason.decode!(conn.resp_body)

      assert Enum.member?(conn.resp_headers, {"content-type", "application/json"})
    end
  end

  test "Should send message batch of max allowed messages and discard the rest" do

    messages = Enum.map(1..15, fn i ->
      %{
        channel_ref: "channel_ref_#{i}",
        message_id: "message_#{i}",
        correlation_id: "correlation_id",
        message_data: "message_data",
        event_name: "event_name"
      }
    end) |> Enum.to_list()

    body =
      Jason.encode!(%{
        messages: messages
      })

    with_mock PubSubCore, [deliver_to_channel: fn(_channel_ref, _msg) ->
      :accepted_connected
     end] do
      conn = conn(:post, "/ext/channel/deliver_batch", body)
        |> put_req_header("content-type", "application/json")

      conn = RestController.call(conn, @options)

      assert conn.status == 202

      result = Jason.decode!(conn.resp_body)
      assert result["result"] == "partial-success"
      assert result["accepted_messages"] == 10
      assert result["discarded_messages"] == 5
      assert length(result["discarded"]) == 5
    end
  end

  test "Should handle invalid messages in a batch" do
    messages = Enum.map(1..5, fn i ->
      ref = if i == 5 do
        ""
      else
        "ref00000_#{i}"
      end
      %{
        channel_ref: ref,
        message_id: "message_#{i}",
        correlation_id: "correlation_id",
        message_data: "message_data",
        event_name: "event_name"
      }
    end) |> Enum.to_list()

    body =
      Jason.encode!(%{
        messages: messages
      })

    with_mock PubSubCore, [deliver_to_channel: fn(_channel_ref, _msg) ->
      :accepted_connected
     end] do
      conn = conn(:post, "/ext/channel/deliver_batch", body)
        |> put_req_header("content-type", "application/json")

      conn = RestController.call(conn, @options)

      assert conn.status == 202

      result = Jason.decode!(conn.resp_body)

      assert result["result"] == "partial-success"
      assert result["accepted_messages"] == 4
      assert result["discarded_messages"] == 1
      assert length(result["discarded"]) == 1
    end
  end

  test "Should handle invalid request batch" do
    body =
      Jason.encode!(%{
        messages: []
      })

    with_mock PubSubCore, [deliver_to_channel: fn(_channel_ref, _msg) ->
      :accepted_connected
     end] do
      conn = conn(:post, "/ext/channel/deliver_batch", body)
        |> put_req_header("content-type", "application/json")

      conn = RestController.call(conn, @options)

      assert conn.status == 400

      result = Jason.decode!(conn.resp_body)

      assert result["error"] == "Invalid request"
      assert result["request"] == %{"messages" => []}

    end
  end

  test "Should handle batch with all messages invalid" do
    body =
      Jason.encode!(%{
        messages: [%{
          channel_ref: "",
          message_id: "message_1",
          correlation_id: "correlation_id",
          message_data: "message_data",
          event_name: "event_name"
        }]
      })

    with_mock PubSubCore, [deliver_to_channel: fn(_channel_ref, _msg) ->
      :accepted_connected
     end] do
      conn = conn(:post, "/ext/channel/deliver_batch", body)
        |> put_req_header("content-type", "application/json")

      conn = RestController.call(conn, @options)

      assert conn.status == 400

      result = Jason.decode!(conn.resp_body)

      assert result["error"] == "Invalid request"
      assert result["request"] == %{"messages" => [%{"channel_ref" => "",
        "correlation_id" => "correlation_id",
        "event_name" => "event_name",
        "message_data" => "message_data",
        "message_id" => "message_1"}]}

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
    body = Jason.encode!(%{application_ref: "some_application", user_ref: "user_ref_00117ALM"})

    with_mocks([
      {PubSubCore, [], [delete_channel: fn(_) -> :ok end]}
    ]) do

      conn2 = conn(:delete, "/ext/channel?channel_ref=xxxx")
      |> put_req_header("accept", "application/json")

      conn2 = RestController.call(conn2, @options)

      assert conn2.status == 200

      assert %{"result" => "Ok"} =
               Jason.decode!(conn2.resp_body)
    end
  end

  test "Should be able to handle call for close unexistent channel" do
    with_mocks([
      {PubSubCore, [], [delete_channel: fn(_) -> :noproc end]}
    ]) do

      # then call for close

      conn2 = conn(:delete, "/ext/channel?channel_ref=xxxx")
      |> put_req_header("accept", "application/json")

      conn2 = RestController.call(conn2, @options)

      assert conn2.status == 410

      assert %{"error" => "Channel not found"} =
               Jason.decode!(conn2.resp_body)

    end
  end

  test "Should be able to handle invalid requesr for close channel" do
    with_mocks([
      {PubSubCore, [], [delete_channel: fn(_) -> :noproc end]}
    ]) do

      conn2 = conn(:delete, "/ext/channel")
      |> put_req_header("accept", "application/json")

      conn2 = RestController.call(conn2, @options)

      assert conn2.status == 400

      assert %{"error" => "Invalid request", "request" => %{}} =
               Jason.decode!(conn2.resp_body)

    end
  end

end
