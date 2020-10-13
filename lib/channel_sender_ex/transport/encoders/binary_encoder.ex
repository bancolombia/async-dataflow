defmodule ChannelSenderEx.Transport.Encoders.BinaryEncoder do
  @moduledoc """
  Encoder for json format
  """
  alias ChannelSenderEx.Transport.MessageEncoder
  alias ChannelSenderEx.Core.ProtocolMessage

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

  def encode_binary({message_id, correlation_id, event_name, message_data, _}) do
    data =
      <<255, byte_size(message_id)::size(8), byte_size(correlation_id)::size(8),
        byte_size(event_name)::size(8), message_id::binary, correlation_id::binary,
        event_name::binary, message_data::binary>>

    {:ok, {:binary, data}}
  end

  def sample_msj() do
    data =
      "Sample data {} \"hello\" -- \"Sample data {} \"hello\" Sample data {} \"hello\" Sample data {} \"hello\" "

    {UUID.uuid4(:hex), "", "tas.event.sample", data, 24_546_342}
  end

  @impl MessageEncoder
  def decode_message(
        <<255, s1, s2, s3, message_id::binary-size(s1), correlation_id::binary-size(s2),
          event_name::binary-size(s3), message_data::binary>>
      ) do
    {message_id, correlation_id, event_name, message_data, 0}
  end

  defp read(<<255, next, rest::binary>>) do
  end
end
