defmodule AdfSenderConnectorTest do
  use ExUnit.Case

  doctest AdfSenderConnector

  import Mock
  alias AdfSenderConnector.Message

  setup_all do
    {:ok, pid} = Finch.start_link(name: SenderHttpClient)
    on_exit(fn -> Process.exit(pid, :normal) end)
    :ok
  end

  test "should exchange credentials" do
    demo_response = %Finch.Response{status: 200,
      body: "{ \"channel_ref\": \"dummy.channel.ref0\", \"channel_secret\": \"yyy0\"}"
    }

    with_mocks([
      {Finch, [], [
        build: fn _, _, _, _ -> {:ok, %{}} end,
        request: fn _, _ -> {:ok, demo_response} end
        ]}
    ]) do
      assert {:ok, %{"channel_ref" => "dummy.channel.ref0", "channel_secret" => "yyy0"}} =
        AdfSenderConnector.channel_registration("a0", "b0")
    end
  end

  test "should fail to register a channel" do
    create_response = {:error, %Mint.TransportError{reason: :econnrefused}}

    with_mocks([
      {Finch, [], [
        build: fn _, _, _, _ -> {:ok, %{}} end,
        request: fn _, _ -> create_response end
        ]}
    ]) do
      {:error, :econnrefused} == AdfSenderConnector.channel_registration("a1", "b1")
    end

  end

  test "deliver a message via channel" do

    create_response = %Finch.Response{
      status: 200,
      body: "{ \"channel_ref\": \"dummy.channel.ref2\", \"channel_secret\": \"yyy2\"}"
    }

    with_mocks([
      {Finch, [], [
        build: fn _, _, _, _ -> {:ok, %{}} end,
        request: fn _, _ -> {:ok, create_response} end
        ]}
    ]) do
      assert {:ok, %{"channel_ref" => "dummy.channel.ref2", "channel_secret" => "yyy2"}}
        == AdfSenderConnector.channel_registration("a2", "b2")
    end

    ### and then try to route a message
    deliver_response = %Finch.Response{
      status: 200,
      body: "{\"result\": \"Ok\"}"
    }

    with_mocks([
      {Finch, [], [
        build: fn _, _, _, _ -> {:ok, %{}} end,
        request: fn _, _ -> {:ok, deliver_response} end
        ]}
    ]) do
      # route a protocol message
      message = Message.new("dummy.channel.ref2", %{"hello" => "world"}, "evt1")
      assert {:ok, %{"result" => "Ok"}} == AdfSenderConnector.route_message(message)

      assert {:ok, %{"result" => "Ok"}} == AdfSenderConnector.route_message("dummy.channel.ref2",
        "0001", "0001", %{"hello" => "world"}, "evt1")

    end
  end

  test "fail to deliver a message via channel" do

    ### first exchange credentials
    create_response = %Finch.Response{
      status: 200,
      body: "{ \"channel_ref\": \"dummy.channel.ref3\", \"channel_secret\": \"yyy3\"}"
    }

    with_mocks([
      {Finch, [], [
        build: fn _, _, _, _ -> {:ok, %{}} end,
        request: fn _, _ -> {:ok, create_response} end
        ]}
    ]) do
      assert {:ok, %{"channel_ref" => "dummy.channel.ref3", "channel_secret" => "yyy3"}}
        == AdfSenderConnector.channel_registration("a3", "b3")
    end

    ### and then try to route a message
    route_response = {:error, %Mint.TransportError{reason: :econnrefused}}

    with_mocks([
      {Finch, [], [
        build: fn _, _, _, _ -> {:ok, %{}} end,
        request: fn _, _ -> route_response end
        ]}
    ]) do
      message = Message.new("dummy.channel.ref3", %{"hello" => "world"}, "evt1")
      assert {:error, :channel_sender_unknown_error} == AdfSenderConnector.route_message(message)
    end

  end

end
