defmodule ChannelSenderEx.Transport.MessageEncoder do
  @moduledoc """
  Definition of generic encoding contract functions
  """
  alias ChannelSenderEx.Core.ProtocolMessage

  @type encoded_type :: :text | :binary
  @type encoded_data :: {encoded_type(), iodata()}

  @callback encode_message(message :: ProtocolMessage.t()) ::
              {:ok, encoded_data()} | {:error, any()}
  @callback decode_message(message :: binary()) :: ProtocolMessage.t()
end
