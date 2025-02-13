Code.compiler_options(ignore_module_conflict: true)

defmodule AdfSenderConnector.RouterTest do
  use ExUnit.Case
  import Mock
  alias AdfSenderConnector.{Message, Router}

  test "should create and route message" do
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
      assert {:ok, %{"result" => "Ok"}} == Router.route_message({"dummy.channel.ref2", "001", "9999", %{"hello" => "world"}, "evt1"})
      # providing nil correlation id, its considered a valid message
      assert {:ok, %{"result" => "Ok"}} == Router.route_message({"dummy.channel.ref2", "001", nil, %{"hello" => "world"}, "evt1"})
    end
  end

  test "should create and route batch of messages" do
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
      messages = [
        Message.new("dummy.channel.ref2", "001", "9999", %{"hello" => "world"}, "evt1"),
        Message.new("dummy.channel.ref2", "002", "9999", %{"hello" => "world"}, "evt1")
      ]

      {:ok, %{"result" => "Ok"}} == Router.route_batch(messages)
    end
  end

  test "should handle route batch of valid/invalid messages" do
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
      messages = [
        Message.new("dummy.channel.ref2", "001", "9999", %{"hello" => "world"}, "evt1"),
        Message.new("", "002", "9999", %{"hello" => "world"}, "evt1")
      ]

      {:ok, %{"result" => "Ok"}} == Router.route_batch(messages)
    end
  end

  test "should not route invalid or incomplete message" do
    assert {:error, :invalid_message} ==
             Router.route_message({nil, "001", "9999", %{"hello" => "world"}, "evt1"})
    assert {:error, :invalid_message} ==
             Router.route_message({"a", nil, "9999", %{"hello" => "world"}, "evt1"})
    assert {:error, :invalid_message} ==
             Router.route_message({"a", "b", "c", nil, "evt1"})
    assert {:error, :invalid_message} ==
             Router.route_message({"a", "b", "c", "d", nil})
  end

end
