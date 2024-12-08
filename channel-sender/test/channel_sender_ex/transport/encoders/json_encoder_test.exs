defmodule ChannelSenderEx.Transport.Encoders.JsonEncoderTest do
  use ExUnit.Case
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Transport.Encoders.JsonEncoder

  setup do
    external_message = %{
      channel_ref: "channel_ref",
      message_id: "message_id2",
      correlation_id: "correlation_id2",
      message_data: "message_data1",
      event_name: "event_name2"
    }

    message = ProtocolMessage.to_protocol_message(external_message)
    {:ok, message: message, external_message: external_message}
  end

  test "should encode to binary", %{message: message} do
    {:ok, {:text, encoded}} = JsonEncoder.encode_message(message)

    decoded_message = JsonEncoder.decode_message(encoded)

    assert ProtocolMessage.to_external_message(decoded_message) ==
             ProtocolMessage.to_external_message(message)
  end

  test "should encode message with UTF-8 special characters to json", %{external_message: message} do
    message = %{
      message
      | message_data:
          "{\"strange_message: \"áéíóú@ñ&%$#!especíalç\", \"strange_message: \"áéíóú@ñ&%$#!especíal2ç\"}"
    }

    message = ProtocolMessage.to_protocol_message(message)
    {:ok, {:text, encoded}} = JsonEncoder.encode_message(message)

    decoded_message = JsonEncoder.decode_message(encoded)

    assert ProtocolMessage.to_external_message(decoded_message) ==
             ProtocolMessage.to_external_message(message)
  end

  test "Should encode Heartbeat Frame" do
    {:text, data} = JsonEncoder.heartbeat_frame("42")
    encoded = :erlang.list_to_binary([data])
    assert {"", "42", ":hb", "", _} = JsonEncoder.decode_message(encoded)
  end

  test "Should encode simple Frame" do
    {:text, iolist} = JsonEncoder.simple_frame("AuthOk")
    encoded = :erlang.list_to_binary(iolist)
    assert {"", "", "AuthOk", "", _} = JsonEncoder.decode_message(encoded)
  end
end
