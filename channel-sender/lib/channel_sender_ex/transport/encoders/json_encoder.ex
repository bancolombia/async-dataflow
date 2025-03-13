defmodule ChannelSenderEx.Transport.Encoders.JsonEncoder do
  @moduledoc """
  Encoder for json format
  """
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Transport.MessageEncoder

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

  @impl MessageEncoder
  def heartbeat_frame(seq) do
    {:text, ["[\"\", \"", seq, "\", \":hb\", \"\"]"]}
  end

  @impl MessageEncoder
  def simple_frame(event) do
    {:text, ["[\"\", \"\", \"", event, "\", \"\"]"]}
  end

  def decode(input, opts \\ []) do
    case Jason.decode(input, opts) do
      {:ok, data} -> data
      {:error, _error} -> %{"payload" => input}
    end
  end
end
