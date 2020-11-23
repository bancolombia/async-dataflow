defmodule ChannelSenderEx.Transport.Encoders.BinaryEncoder do
  @moduledoc """
  Encoder for json format
  """
  alias ChannelSenderEx.Transport.MessageEncoder

  @behaviour MessageEncoder

  @impl MessageEncoder
  def encode_message({message_id, correlation_id, event_name, message_data, _}) do
    data = [
      255,
      byte_size(message_id),
      byte_size(correlation_id),
      byte_size(event_name),
      message_id,
      correlation_id,
      event_name,
      message_data
    ]

    {:ok, {:binary, data}}
  end

  @impl MessageEncoder
  def heartbeat_frame(seq) do
    {:ok, result} = encode_message({"", seq, ":hb", "", nil})
    result
  end

  @impl MessageEncoder
  def simple_frame(event) do
    {:ok, result} = encode_message({"", "", event, "", nil})
    result
  end

  @impl MessageEncoder
  def decode_message(
        <<255, s1, s2, s3, message_id::binary-size(s1), correlation_id::binary-size(s2),
          event_name::binary-size(s3), message_data::binary>>
      ) do
    {message_id, correlation_id, event_name, message_data, 0}
  end
end
