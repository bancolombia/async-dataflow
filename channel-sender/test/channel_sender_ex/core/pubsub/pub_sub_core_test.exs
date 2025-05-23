defmodule ChannelSenderEx.Core.PubSub.PubSubCoreTest do
  use ExUnit.Case

  alias ChannelSenderEx.Core.Channel
  alias ChannelSenderEx.Core.ChannelSupervisor
  alias ChannelSenderEx.Core.PubSub.PubSubCore

  import Mock

  test "should deliver to channel" do
    with_mocks([
      {ChannelSupervisor, [], [
        related_channels: fn(_) -> [:c.pid(0, 255, 0)] end
      ]},
      {Channel, [], [deliver_message: fn(_, _) -> :accepted_connected end]}
    ]) do
      assert :ok == PubSubCore.deliver_to_channel("channel_ref", %{})
      assert_called_exactly ChannelSupervisor.related_channels("channel_ref"), 1
    end
  end

  test "should retry when channel not found" do
    with_mock(
      ChannelSupervisor, [related_channels: fn(_) -> :undefined end]
    ) do
      assert :error == PubSubCore.deliver_to_channel("channel_ref", %{})
      assert_called_exactly ChannelSupervisor.related_channels("channel_ref"), 10
    end
  end

  test "should deliver to all channels associated with the given user reference" do
    with_mocks([
      {Channel, [], [deliver_message: fn(_, _) -> :accepted_connected end]}
    ]) do
      assert %{accepted_connected: 0, accepted_waiting: 0} == PubSubCore.deliver_to_user_channels("user_ref", %{})
      assert_called_exactly Channel.deliver_message(:_, :_), 0
    end
  end

  test "should handle call to delete (end) non-existent channel" do
    with_mock(
      ChannelSupervisor, [whereis_channel: fn(_) -> :undefined end]
    ) do
      assert :ok == PubSubCore.delete_channel("channel_ref")
    end
  end

  test "should handle call to delete (end) existent channel" do
    with_mocks([
      {ChannelSupervisor, [], [whereis_channel: fn(_) -> :c.pid(0, 255, 0) end]}
    ]) do
      assert :ok == PubSubCore.delete_channel("channel_ref")
    end
  end

end
