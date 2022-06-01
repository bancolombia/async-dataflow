Code.compiler_options(ignore_module_conflict: true)

defmodule AdfSenderConnector.MessageTest do
  use ExUnit.Case

  alias AdfSenderConnector.Message

  @moduletag :capture_log

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

end
