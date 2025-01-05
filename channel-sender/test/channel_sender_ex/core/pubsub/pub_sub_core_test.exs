defmodule ChannelSenderEx.Core.PubSub.PubSubCoreTest do
  use ExUnit.Case

  alias ChannelSenderEx.Core.Channel
  alias ChannelSenderEx.Core.ChannelRegistry
  alias ChannelSenderEx.Core.PubSub.PubSubCore

  import Mock

  test "should deliver to channel" do
    with_mocks([
      {ChannelRegistry, [], [
        lookup_channel_addr: fn(_) -> :c.pid(0, 255, 0) end
      ]},
      {Channel, [], [deliver_message: fn(_, _) -> :accepted_connected end]}
    ]) do
      assert :accepted_connected == PubSubCore.deliver_to_channel("channel_ref", %{})
      assert_called_exactly ChannelRegistry.lookup_channel_addr("channel_ref"), 1
    end
  end

  test "should retry when channel not found" do
    with_mock(
      ChannelRegistry, [lookup_channel_addr: fn(_) -> :noproc end]
    ) do
      assert :error == PubSubCore.deliver_to_channel("channel_ref", %{})
      assert_called_exactly ChannelRegistry.lookup_channel_addr("channel_ref"), 10
    end
  end

  test "should deliver to all channels associated with the given application reference" do
    with_mocks([
      {ChannelRegistry, [], [
        query_by_app: fn(_) -> [:c.pid(0, 255, 0), :c.pid(0, 254, 0)] end
      ]},
      {Channel, [], [deliver_message: fn(_, _) -> :accepted_connected end]}
    ]) do
      assert  %{accepted_connected: 2} == PubSubCore.deliver_to_app_channels("app_ref", %{})
      assert_called_exactly ChannelRegistry.query_by_app("app_ref"), 1
      assert_called_exactly Channel.deliver_message(:_, :_), 2
    end
  end

  test "should deliver to all channels associated with the given user reference" do
    with_mocks([
      {ChannelRegistry, [], [
        query_by_user: fn(_) -> [:c.pid(0, 255, 0), :c.pid(0, 254, 0)] end
      ]},
      {Channel, [], [deliver_message: fn(_, _) -> :accepted_connected end]}
    ]) do
      assert  %{accepted_connected: 2} == PubSubCore.deliver_to_user_channels("user_ref", %{})
      assert_called_exactly ChannelRegistry.query_by_user("user_ref"), 1
      assert_called_exactly Channel.deliver_message(:_, :_), 2
    end
  end

end
