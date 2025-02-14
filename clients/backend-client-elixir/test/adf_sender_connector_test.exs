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
    ### try to route a message
    deliver_response = %Finch.Response{
      status: 202,
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

  test "deliver messages in batch" do
    ### try to route a message
    deliver_response = %Finch.Response{
      status: 202,
      body: "{\"result\": \"Ok\"}"
    }

    with_mocks([
      {Finch, [], [
        build: fn _, _, _, _ -> {:ok, %{}} end,
        request: fn _, _ -> {:ok, deliver_response} end
      ]}
    ]) do
      # route a protocol message
      messages = [
        Message.new("dummy.channel.ref2", %{"hello" => "world"}, "evt1"),
        Message.new("dummy.channel.ref3", %{"hello" => "world"}, "evt1")
      ]

      assert {:ok, %{"result" => "Ok"}} == AdfSenderConnector.route_batch(messages)
    end
  end

  test "fail to deliver a message via channel" do

    ### try to route a message
    route_response = {:error, %Mint.TransportError{reason: :econnrefused}}

    with_mocks([
      {Finch, [], [
        build: fn _, _, _, _ -> {:ok, %{}} end,
        request: fn _, _ -> route_response end
      ]}
    ]) do
      message = Message.new("dummy.channel.ref3", %{"hello" => "world"}, "evt1")
      assert {:error, :unknown_error} == AdfSenderConnector.route_message(message)
    end

  end

  test "should handle closing channel" do

    deliver_response = %Finch.Response{
      status: 202,
      body: "{\"result\": \"Ok\"}"
    }
    with_mocks([
      {Finch, [], [
        build: fn _, _, _, _ -> {:ok, %{}} end,
        request: fn _, _ -> {:ok, deliver_response} end
      ]}
    ]) do

      assert {:ok, %{"result" => "Ok"}} == AdfSenderConnector.channel_close("dummy.channel.ref4")
    end
  end

end
