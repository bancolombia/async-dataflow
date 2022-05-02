defmodule AdfSenderConnectorTest do
  use ExUnit.Case
  doctest AdfSenderConnector
  import Mock
  alias AdfSenderConnector.Message

  setup do
    HTTPoison.start
   :ok
  end

  test "create a channel" do
    options = [name: :demo4, sender_url: "http://localhost:8082"]
    {:ok, pid} = AdfSenderConnector.start_link(options)

    create_response = %HTTPoison.Response{
      status_code: 200,
      body: "{ \"channel_ref\": \"xxx\", \"channel_secret\": \"yyy\"}"
    }

    with_mocks([
      {HTTPoison, [], [post: fn _url, _params, _headers, _opts -> {:ok, create_response} end]}
    ]) do

      assert {:ok, %{channel_ref: "xxx", channel_secret: "yyy"}} = AdfSenderConnector.create_channel(:demo4, "a", "b")

    end

    Process.exit(pid, :normal)
  end

  test "fail to create a channel" do
    options = [name: :demo5, sender_url: "http://localhost:8082"]
    {:ok, pid} = AdfSenderConnector.start_link(options)
    assert {:error, :channel_sender_econnrefused} = AdfSenderConnector.create_channel(:demo5, "a", "b")
    Process.exit(pid, :normal)
  end

  test "deliver a message via channel" do
    options = [name: :demo6, sender_url: "http://localhost:8082"]
    {:ok, pid} = AdfSenderConnector.start_link(options)

    create_response = %HTTPoison.Response{
      status_code: 200,
      body: "{ \"channel_ref\": \"xxx\", \"channel_secret\": \"yyy\"}"
    }

    deliver_response = %HTTPoison.Response{
      status_code: 200,
      body: "{ \"result\": \"Ok\" }"
    }

    with_mocks([
      {HTTPoison, [], [post: fn url, _params, _headers, _opts ->
        case String.contains?(url, "/ext/channel/create") do
          true -> {:ok, create_response}
          false -> {:ok, deliver_response}
        end
      end]}
    ]) do

      response_ch_openning = AdfSenderConnector.create_channel(:demo6, "a", "b")
      assert {:ok, %{channel_ref: "xxx", channel_secret: "yyy"}} = response_ch_openning

      message = Message.new("ref1", %{"hello" => "world"}, "evt1")
      response_msg_deliver = AdfSenderConnector.deliver_message(:demo6, message)
      assert {:ok, %{result: "Ok"}} = response_msg_deliver

      response_msg_deliver2 = AdfSenderConnector.deliver_message(:demo6, "ch1", "evt1", %{"hello" => "world"})
      assert {:ok, %{result: "Ok"}} = response_msg_deliver2

    end

    Process.exit(pid, :normal)
  end

  test "fail to deliver a message via channel" do
    options = [name: :demo7, sender_url: "http://localhost:8082"]
    {:ok, pid} = AdfSenderConnector.start_link(options)

    create_response = %HTTPoison.Response{
      status_code: 200,
      body: "{ \"channel_ref\": \"xxx\", \"channel_secret\": \"yyy\"}"
    }

    deliver_response = %HTTPoison.Response{
      status_code: 500,
      body: "{ \"error\": \"some error desc\" }"
    }

    with_mocks([
      {HTTPoison, [], [post: fn url, _params, _headers, _opts ->
        case String.contains?(url, "/ext/channel/create") do
          true -> {:ok, create_response}
          false -> {:ok, deliver_response}
        end
      end]}
    ]) do

      response_ch_openning = AdfSenderConnector.create_channel(:demo7, "a", "b")
      assert {:ok, %{channel_ref: "xxx", channel_secret: "yyy"}} = response_ch_openning

      message = Message.new("ref1", %{"hello" => "world"}, "evt1")
      response_msg_deliver = AdfSenderConnector.deliver_message(:demo7, message)
      assert {:error, :channel_sender_unknown_error} = response_msg_deliver

    end

    Process.exit(pid, :normal)
  end

end
