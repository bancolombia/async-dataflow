defmodule ChannelSenderEx.Core.PubSub.PubSubCoreTest do
  use ExUnit.Case

  alias ChannelSenderEx.Core.ChannelRegistry
  alias ChannelSenderEx.Core.PubSub.PubSubCore
  import Mock

  test "should retry when channel not found" do

    with_mock(
      ChannelRegistry, [lookup_channel_addr: fn(_) -> :noproc end]
    ) do

      assert :error == PubSubCore.deliver_to_channel("channel_ref", %{})

    end

  end

end
