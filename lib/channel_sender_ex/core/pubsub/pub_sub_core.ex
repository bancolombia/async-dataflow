defmodule ChannelSenderEx.Core.PubSub.PubSubCore do
  @moduledoc """
  Handles channel delivery and discovery logic
  """

  @type channel_ref() :: String.t()
  @type message_id() :: String.t()
  @type event_name() :: String.t()
  @type message_data() :: iodata()
  @type message() :: {message_id(), event_name(), message_data()}

  @spec deliver_to_channel(channel_ref(), message()) :: :ok
  def deliver_to_channel(channel_ref, message) do
    :ok
  end
end
