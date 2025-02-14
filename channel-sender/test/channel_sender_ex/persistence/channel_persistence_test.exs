defmodule ChannelSenderEx.Persistence.ChannelPersistenceTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ChannelSenderEx.Core.Channel.Data
  alias ChannelSenderEx.Persistence.ChannelPersistence

  test "save_channel_data/1 delegates to the implementation module" do
    data = %Data{channel: "channel_1"}

    assert :ok == ChannelPersistence.save_channel_data(data)
  end

  test "delete_channel_data/1 delegates to the implementation module" do
    channel_id = "channel_1"

    assert :ok == ChannelPersistence.delete_channel_data(channel_id)
  end

  test "get_channel_data/1 delegates to the implementation module" do
    channel_id = "channel_1"

    assert {:error, :not_found} = ChannelPersistence.get_channel_data(channel_id)
  end

  test "child_spec/0 returns empty list when persistence is disabled" do
    Application.put_env(:channel_sender_ex, :persistence, enabled: false)

    assert [] = ChannelPersistence.child_spec()
  end

  test "child_spec/0 returns empty list when persistence is noop" do
    Application.put_env(:channel_sender_ex, :persistence, enabled: true, type: :noop)

    assert [] = ChannelPersistence.child_spec()
  end
end
