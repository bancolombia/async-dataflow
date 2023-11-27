defmodule AdfSenderConnectorTest do
  use ExUnit.Case
  doctest AdfSenderConnector
  import Mock
  alias AdfSenderConnector.Message

  @sender_url "http://localhost:8888"
  setup_all do

    children = [
      AdfSenderConnector.spec([sender_url: @sender_url]),
      AdfSenderConnector.registry_spec()
    ]

    Supervisor.start_link(children, strategy: :one_for_one)

   :ok
  end

  test "should exchange credentials" do

    options = [sender_url: @sender_url, http_opts: []]

    create_response = %HTTPoison.Response{
      status_code: 200,
      body: "{ \"channel_ref\": \"dummy.channel.ref0\", \"channel_secret\": \"yyy0\"}"
    }

    with_mocks([
      {HTTPoison, [], [post: fn _url, _params, _headers, _opts -> {:ok, create_response} end]}
    ]) do
      assert {:ok, %{"channel_ref" => "dummy.channel.ref0", "channel_secret" => "yyy0"}} =
        AdfSenderConnector.channel_registration("a0", "b0", options)
    end

  end

  test "should fail to register a channel" do
    options = [http_opts: []]
    assert {:error, :channel_sender_econnrefused} == AdfSenderConnector.channel_registration("a1", "b1", options)
  end

  # test "fail to create a process due to invalid options" do
  #   options = [name: :xxx, alpha: true]

  #   assert_raise NimbleOptions.ValidationError, fn ->
  #     AdfSenderConnector.channel_registration("a2", "b2", options)
  #   end

  # end

  test "deliver a message via channel" do

    ### first exchange credentials
    options = [sender_url: @sender_url, http_opts: []]

    create_response = %HTTPoison.Response{
      status_code: 200,
      body: "{ \"channel_ref\": \"dummy.channel.ref2\", \"channel_secret\": \"yyy2\"}"
    }

    with_mocks([
      {HTTPoison, [], [post: fn _url, _params, _headers, _opts -> {:ok, create_response} end]}
    ]) do
      assert {:ok, %{"channel_ref" => "dummy.channel.ref2", "channel_secret" => "yyy2"}}
        == AdfSenderConnector.channel_registration("a2", "b2", options)
    end

    ### then create a process to map that name
    AdfSenderConnector.start_router_process("dummy.channel.ref2")

    ### and then try to route a message
    deliver_response = %HTTPoison.Response{
      status_code: 200,
      body: "{ \"result\": \"Ok\" }"
    }

    with_mocks([
      {HTTPoison, [], [post: fn _url, _params, _headers, _opts -> {:ok, deliver_response} end]}
    ]) do

      # route a protocol message
      message = Message.new("dummy.channel.ref2", %{"hello" => "world"}, "evt1")
      assert {:ok, %{"result" => "Ok"}} == AdfSenderConnector.route_message("dummy.channel.ref2", "evt1", message)

      # route data represented as a Map
      assert {:ok, %{"result" => "Ok"}} == AdfSenderConnector.route_message("dummy.channel.ref2", "evt1", %{"hello" => "world"})
    end

  end

  test "fail to deliver a message via channel" do

    options = [sender_url: @sender_url, http_opts: []]

    ### first exchange credentials
    create_response = %HTTPoison.Response{
      status_code: 200,
      body: "{ \"channel_ref\": \"dummy.channel.ref3\", \"channel_secret\": \"yyy3\"}"
    }

    with_mocks([
      {HTTPoison, [], [post: fn _url, _params, _headers, _opts -> {:ok, create_response} end]}
    ]) do
      assert {:ok, %{"channel_ref" => "dummy.channel.ref3", "channel_secret" => "yyy3"}}
        == AdfSenderConnector.channel_registration("a3", "b3", options)
    end

    ### then create a process to map that name
    AdfSenderConnector.start_router_process("dummy.channel.ref3")

    ### and then try to route a message
    deliver_response = %HTTPoison.Response{
      status_code: 500,
      body: "{ \"error\": \"some error desc\" }"
    }

    with_mocks([
      {HTTPoison, [], [post: fn _url, _params, _headers, _opts -> {:ok, deliver_response} end]}
    ]) do

      message = Message.new("dummy.channel.ref3", %{"hello" => "world"}, "evt1")
      assert {:error, :channel_sender_unknown_error} == AdfSenderConnector.route_message("dummy.channel.ref3", "evt1", message)
    end

  end

end
