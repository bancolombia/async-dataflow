defmodule AdfSenderConnectorTest do
  use ExUnit.Case
  doctest AdfSenderConnector
  import Mock
  alias AdfSenderConnector.Message

  @sender_url "http://localhost:8889"
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
    options = [sender_url: @sender_url, http_opts: []]

    create_response = {:error, %{reason: :econnrefused}}

    with_mocks([
      {HTTPoison, [], [post: fn _url, _params, _headers, _opts -> create_response end]}
    ]) do
      {:error, :channel_sender_econnrefused} == AdfSenderConnector.channel_registration("a1", "b1", options)
    end

  end

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

  test "should route via cast" do

    options = [sender_url: @sender_url, http_opts: []]

    ### first exchange credentials
    create_response = %HTTPoison.Response{
      status_code: 200,
      body: "{ \"channel_ref\": \"dummy.channel.ref4\", \"channel_secret\": \"yyy4\"}"
    }

    with_mocks([
      {HTTPoison, [], [post: fn _url, _params, _headers, _opts -> {:ok, create_response} end]}
    ]) do
      assert {:ok, %{"channel_ref" => "dummy.channel.ref4", "channel_secret" => "yyy4"}}
        == AdfSenderConnector.channel_registration("a4", "b4", options)
    end

    ### then create a process to map that name
    AdfSenderConnector.start_router_process("dummy.channel.ref4")

    ### and then try to route a message
    deliver_response = %HTTPoison.Response{
      status_code: 200,
      body: "{ \"result\": \"Ok\" }"
    }

    with_mocks([
      {HTTPoison, [], [post: fn _url, _params, _headers, _opts -> {:ok, deliver_response} end]}
    ]) do

      assert :ok == AdfSenderConnector.route_message("dummy.channel.ref4", "evt1", %{}, [cast: true])

      message = Message.new("dummy.channel.ref4", %{"hello" => "world"}, "evt1")

      assert :ok == AdfSenderConnector.route_message("dummy.channel.ref4", "evt1", message, [cast: true])
    end

  end

  test "should stop routing process" do

    options = [sender_url: @sender_url, http_opts: []]

    ### first exchange credentials
    create_response = %HTTPoison.Response{
      status_code: 200,
      body: "{ \"channel_ref\": \"dummy.channel.ref5\", \"channel_secret\": \"yyy5\"}"
    }

    with_mocks([
      {HTTPoison, [], [post: fn _url, _params, _headers, _opts -> {:ok, create_response} end]}
    ]) do
      assert {:ok, %{"channel_ref" => "dummy.channel.ref5", "channel_secret" => "yyy5"}}
             == AdfSenderConnector.channel_registration("a5", "b5", options)
    end

    ### then create a process to map that name
    {:ok, _pid} = AdfSenderConnector.start_router_process("dummy.channel.ref5")

    ### and then stop the router process
    assert :ok == AdfSenderConnector.stop_router_process("dummy.channel.ref5")


  end

end
