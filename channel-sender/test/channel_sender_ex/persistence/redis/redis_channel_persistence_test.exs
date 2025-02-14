defmodule ChannelSenderEx.Persistence.RedisChannelPersistenceTest do
  use ExUnit.Case, async: true
  import Mock

  alias ChannelSenderEx.Persistence.RedisChannelPersistence
  alias ChannelSenderEx.Core.Channel.Data

  test "save_channel_data/1 saves data to Redis" do
    data = %Data{channel: "channel_1", application: "value"}
    Application.put_env(:channel_sender_ex, :persistence_ttl, 50)

    with_mock Redix,
      noreply_command: fn :redix_write, ["SETEX", "channel_1", 50, _encoded_data] -> :ok end do
      assert :ok == RedisChannelPersistence.save_channel_data(data)
    end
  end

  test "get_channel_data/1 retrieves data from Redis" do
    encoded_data = Jason.encode!(%Data{channel: "channel_1", application: "value", pending_ack: %{keys: []}, pending_sending: %{keys: []}})
    data = %Data{channel: "channel_1", application: "value", pending_ack: {%{}, []}, pending_sending: {%{}, []}}

    with_mock Redix, command: fn :redix_read, ["GET", "channel_1"] -> {:ok, encoded_data} end do
      assert {:ok, ^data} = RedisChannelPersistence.get_channel_data("channel_1")
    end
  end

  test "get_channel_data/1 returns :not_found when data is not in Redis" do
    with_mock Redix, command: fn :redix_read, ["GET", "channel_1"] -> {:ok, nil} end do
      assert {:error, :not_found} == RedisChannelPersistence.get_channel_data("channel_1")
    end
  end

  test "child_spec/0 returns child spec when persistence is enabled" do
    Application.put_env(:channel_sender_ex, :persistence, enabled: true, config: [])

    with_mock ChannelSenderEx.Persistence.RedisSupervisor, spec: fn _ -> :child_spec end do
      assert [:child_spec] == RedisChannelPersistence.child_spec()
    end
  end

  test "child_spec/0 returns empty list when persistence is disabled" do
    Application.put_env(:channel_sender_ex, :persistence, enabled: false)

    expected = [
      %{
        id: ChannelSenderEx.Persistence.RedisSupervisor,
        start: {ChannelSenderEx.Persistence.RedisSupervisor, :start_link, [[]]},
        type: :supervisor
      }
    ]

    assert expected == RedisChannelPersistence.child_spec()
  end
end
