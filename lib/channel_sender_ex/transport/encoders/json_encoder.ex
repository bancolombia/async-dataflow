defmodule ChannelSenderEx.Transport.Encoders.JsonEncoder do
  @moduledoc """
  Encoder for json format
  """
  alias ChannelSenderEx.Transport.MessageEncoder
  alias ChannelSenderEx.Core.ProtocolMessage

  @behaviour MessageEncoder

  @impl MessageEncoder
  def encode_message(message) do
    case Jason.encode(ProtocolMessage.to_socket_message(message)) do
      {:ok, data} -> {:ok, {:text, data}}
      err -> err
    end
  end

  @impl MessageEncoder
  def decode_message(message) do
    Jason.decode!(message) |> ProtocolMessage.from_socket_message()
  end

  def heartbeat_frame(seq) do
    {:text, ["[\"\", \"", seq, "\", \":hb\", \"\"]"]}
  end

  def simple_frame(event) do
    {:text, ["[\"\", \"\", \"", event, "\", \"\"]"]}
  end
end
