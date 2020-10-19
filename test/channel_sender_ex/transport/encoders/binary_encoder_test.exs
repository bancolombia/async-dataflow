defmodule ChannelSenderEx.Transport.Encoders.BinaryEncoderTest do
  use ExUnit.Case
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Transport.Encoders.BinaryEncoder


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
    {:ok, {:binary, iolist_data}} = BinaryEncoder.encode_message(message)
    encoded = :erlang.list_to_binary(iolist_data)
    assert is_binary(encoded)

    decoded_message = BinaryEncoder.decode_message(encoded)

    assert ProtocolMessage.to_external_message(decoded_message) == ProtocolMessage.to_external_message(message)
    IO.inspect(encoded, limit: :infinity)
  end

  test "should encode message with UTF-8 special characters to binary", %{external_message: message} do
    message = %{message | message_data: "{\"strange_message: \"áéíóú@ñ&%$#!especíalç\", \"strange_message: \"áéíóú@ñ&%$#!especíal2ç\"}"}
    message = ProtocolMessage.to_protocol_message(message)
    {:ok, {:binary, iolist_data}} = BinaryEncoder.encode_message(message)
    encoded = :erlang.list_to_binary(iolist_data)
    assert is_binary(encoded)

    decoded_message = BinaryEncoder.decode_message(encoded)

    assert ProtocolMessage.to_external_message(decoded_message) == ProtocolMessage.to_external_message(message)
    IO.inspect(encoded, limit: :infinity)
  end

  test "Should encode Heartbeat Frame" do
    {:binary, iolist} = BinaryEncoder.heartbeat_frame("42")
    encoded = :erlang.list_to_binary(iolist)
    assert {"", "42", ":hb", "", 0} == BinaryEncoder.decode_message(encoded)
  end

  test "Should encode simple Frame" do
    {:binary, iolist} = BinaryEncoder.simple_frame("AuthOk")
    encoded = :erlang.list_to_binary(iolist)
    assert {"", "", "AuthOk", "", 0} == BinaryEncoder.decode_message(encoded)
  end


end
