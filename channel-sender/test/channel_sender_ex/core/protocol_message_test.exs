defmodule ChannelSenderEx.Core.ProtocolMessageTest do
  use ExUnit.Case
  alias ChannelSenderEx.Core.ProtocolMessage

  test "should convert to ProtocolMessage" do
    external_message = %{
      "channel_ref" => "channel_ref",
      "message_id" => "message_id2",
      "correlation_id" => "correlation_id2",
      "message_data" => "message_data1",
      "event_name" => "event_name2"
    }

    message = ProtocolMessage.to_protocol_message(external_message)
    assert {"message_id2", "correlation_id2", "event_name2", "message_data1", timestamp} = message
    assert is_number(timestamp)
  end

  test "should convert to socket message" do
    protocol_message =
      {"message_id2", "correlation_id2", "event_name2", "message_data1", _timestamp = 14_532_123}

    socket_message = ProtocolMessage.to_socket_message(protocol_message)
    assert socket_message == ["message_id2", "correlation_id2", "event_name2", "message_data1"]
  end
end
