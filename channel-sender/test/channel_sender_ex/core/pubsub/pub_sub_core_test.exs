defmodule ChannelSenderEx.Core.PubSub.PubSubCoreTest do
  use ExUnit.Case

  alias ChannelSenderEx.Core.Channel
  alias ChannelSenderEx.Core.PubSub.PubSubCore

  import Mock

  test "should deliver to channel" do
    with_mocks([
      {Cachex, [], [
        get: fn(_, _) -> {:ok, :c.pid(0, 255, 0)} end
      ]},
      {Channel, [], [deliver_message: fn(_, _) -> :accepted_connected end]}
    ]) do
      assert :accepted_connected == PubSubCore.deliver_to_channel("channel_ref", %{})
      assert_called_exactly Cachex.get(:channels, "channel_ref"), 1
    end
  end

  test "should retry when channel not found" do
    with_mock(
      Cachex, [get: fn(_, _) -> {:ok, nil} end]
    ) do
      assert :error == PubSubCore.deliver_to_channel("channel_ref", %{})
      assert_called_exactly Cachex.get(:channels, "channel_ref"), 10
    end
  end

  # No implementado con Cachex
  # test "should deliver to all channels associated with the given application reference" do
  #   with_mocks([
  #     {Swarm, [], [
  #       members: fn(_) -> [:c.pid(0, 255, 0), :c.pid(0, 254, 0)] end
  #     ]},
  #     {Channel, [], [deliver_message: fn(_, _) -> :accepted_connected end]}
  #   ]) do
  #     assert  %{accepted_connected: 2} == PubSubCore.deliver_to_app_channels("app_ref", %{})
  #     assert_called_exactly Swarm.members("app_ref"), 1
  #     assert_called_exactly Channel.deliver_message(:_, :_), 2
  #   end
  # end

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
      Cachex, [get: fn(_, _) -> {:ok, nil} end]
    ) do
      assert :ok == PubSubCore.delete_channel("channel_ref")
    end
  end

  test "should handle call to delete (end) existent channel" do
    with_mocks([
      {Cachex, [], [get: fn(_, _) -> {:ok, :c.pid(0, 255, 0)} end]},
      {Channel, [], [stop: fn(_) -> :ok end]}
    ]) do
      assert :ok == PubSubCore.delete_channel("channel_ref")
    end
  end

end
