
defmodule ChannelSenderEx.Persistence.ChannelPersistenceTest do
  use ExUnit.Case

  alias ChannelSenderEx.Persistence.ChannelPersistence

  @moduletag :capture_log

  test "Should save data" do
    assert :ok == ChannelPersistence.save_channel("channel", "socket")
  end

  test "Should save socket" do
    assert :ok == ChannelPersistence.save_socket("channel", "socket")
  end

  test "Should save message" do
    assert :ok == ChannelPersistence.save_message("channel_ref", "message_id", "message")
  end

  test "Should delete channel" do
    assert :ok == ChannelPersistence.delete_channel("channel")
  end

  test "Should delete socket" do
    assert :ok == ChannelPersistence.delete_socket("socket")
  end

  test "Should delete message" do
    assert :ok == ChannelPersistence.delete_message("channel_ref", "message_id")
  end

  test "Should get channel" do
    assert {:error, :not_found} == ChannelPersistence.get_channel("channel")
  end

  test "Should get socket" do
    assert {:error, :not_found} == ChannelPersistence.get_socket("socket")
  end

  test "Should get message" do
    assert {:ok, []} == ChannelPersistence.get_message("message_id")
  end
end
