defmodule ChannelSenderEx.Core.PubSub.PubSubCore do
  @moduledoc """
  Handles channel delivery and discovery logic
  """
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.Channel
  alias ChannelSenderEx.Core.ChannelRegistry

  @type channel_ref() :: String.t()

  @spec deliver_to_channel(channel_ref(), ProtocolMessage.t()) :: any()
  def deliver_to_channel(channel_ref, message) do
    channel_addr = ChannelRegistry.lookup_channel_addr(channel_ref)
    Channel.deliver_message(channel_addr, message)
  end
end
