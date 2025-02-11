Code.compiler_options(ignore_module_conflict: true)

defmodule AdfSenderConnector.MessageTest do
  use ExUnit.Case

  alias AdfSenderConnector.Message

  test "should create new message - minimal data" do
    message = Message.new("ref", %{"hello" => "world"}, "user.created")
    assert "ref" == message.channel_ref
    assert nil == message.correlation_id
    assert "user.created" == message.event_name
    assert %{"hello" => "world"} == message.message_data
    assert nil != message.message_id
  end

  test "should create new message - all attributes" do
    message = Message.new("ref", "id1", "co1", %{"hello" => "world"}, "user.created")
    assert "ref" == message.channel_ref
    assert "co1" == message.correlation_id
    assert "user.created" == message.event_name
    assert %{"hello" => "world"} == message.message_data
    assert "id1" == message.message_id
  end

  test "should assert if required data is present" do
    message = Message.new("ref", "id1", "co1", %{"hello" => "world"}, "user.created")
    assert {:ok, _} = Message.assert_valid(message)

    message = Message.new("", "id1", "co1", %{"hello" => "world"}, "user.created")
    assert {:error, :invalid_message} = Message.assert_valid(message)
  end

  test "should process validation of a list of messages" do
    messages = [Message.new("ref", "id1", "co1", %{"hello" => "world"}, "user.created"),
                Message.new("", "id1", "co1", %{"hello" => "world"}, "user.created")]

    validated_messages = Message.validate(messages)

    assert length(validated_messages) == 1
  end

end
