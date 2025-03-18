
defmodule ChannelSenderEx.Persistence.RedisChannelPersistenceTest do
  use ExUnit.Case
  import Mock

  alias ChannelSenderEx.Persistence.RedisChannelPersistence

  @moduletag :capture_log

  test "Should save data" do
    with_mocks([
      {Redix, [], [
        noreply_command: fn(_, _) -> :ok end,
        noreply_pipeline: fn(_, _) -> :ok end
      ]}
    ]) do
      assert :ok == RedisChannelPersistence.save_channel("channel", "socket")
      assert :ok == RedisChannelPersistence.save_socket("socket", "channel")
      assert :ok == RedisChannelPersistence.save_message("message_id", "message")
    end
  end

  test "Should handle fail saving data" do
    with_mocks([
      {Redix, [], [
        noreply_command: fn(_, _) -> raise("Dummy fail") end,
        noreply_pipeline: fn(_, _) -> raise("Dummy fail") end
      ]}
    ]) do
      assert :ok == RedisChannelPersistence.save_channel("channel", "socket")
      assert :ok == RedisChannelPersistence.save_socket("socket", "channel")
      assert :ok == RedisChannelPersistence.save_message("message_id", "message")
    end
  end

  test "Should delete data" do
    with_mocks([
      {Redix, [], [
        noreply_command: fn(_, _) -> :ok end,
        noreply_pipeline: fn(_, _) -> :ok end
      ]}
    ]) do
      assert :ok == RedisChannelPersistence.delete_channel("channel", "socket")
      assert :ok == RedisChannelPersistence.delete_socket("socket", "channel")
      assert :ok == RedisChannelPersistence.delete_message("message_id")
    end
  end

  test "Should handle fail on delete data" do
    with_mocks([
      {Redix, [], [
        noreply_command: fn(_, _) -> raise("Dummy fail") end,
        noreply_pipeline: fn(_, _) -> raise("Dummy fail") end
      ]}
    ]) do
      assert :ok == RedisChannelPersistence.delete_channel("channel", "socket")
      assert :ok == RedisChannelPersistence.delete_socket("socket", "channel")
      assert :ok == RedisChannelPersistence.delete_message("message_id")
    end
  end

  test "Should get data" do
    with_mocks([
      {Redix, [], [
        command: fn(:redix_read, ["GET", key]) ->
          case key do
            "channel_channel" -> {:ok, "socket"}
            "socket_socket" -> {:ok, "channel"}
          end
        end,
        pipeline: fn(_, _) -> {:ok, ["socket", "message"]} end
      ]}
    ]) do
      assert {:ok, "socket"} == RedisChannelPersistence.get_channel("channel")
      assert {:ok, "channel"} == RedisChannelPersistence.get_socket("socket")
      assert {:ok, ["socket", "message"]} == RedisChannelPersistence.get_message("message_id", "channel")
    end

  end

  test "Should handle fail getting data" do
    with_mocks([
      {Redix, [], [
        command: fn(_, _) -> raise("Dummy fail") end,
        pipeline: fn(_, _) -> raise("Dummy fail") end
      ]}
    ]) do
      assert {:error, :not_found} == RedisChannelPersistence.get_channel("channel")
      assert {:error, :not_found} == RedisChannelPersistence.get_socket("socket")
      assert {:error, :not_found} == RedisChannelPersistence.get_message("message_id", "channel")
    end

  end


end
