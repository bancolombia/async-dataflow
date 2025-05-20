defmodule ChannelSenderEx.Core.Security.ChannelAuthenticatorTest do
  use ExUnit.Case

  alias ChannelSenderEx.Core.ChannelSupervisor
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator

  import Mock

  @moduletag :capture_log

  setup_all do
    Application.put_env(:channel_sender_ex, :secret_base, {
      "aV4ZPOf7T7HX6GvbhwyBlDM8B9jfeiwi+9qkBnjXxUZXqAeTrehojWKHkV3U0kGc",
      "socket auth"
    })
    Application.put_env(:channel_sender_ex, :channel_shutdown_tolerance, 100)
    Application.put_env(:channel_sender_ex, :max_age, 100)

    {:ok, _} = Application.ensure_all_started(:plug_crypto)

    :ok
  end

  test "Should create channel" do
    with_mocks([
      {ChannelSupervisor, [], [
        start_channel: fn(_) -> {:ok, :c.pid(0, 255, 0)} end,
        register_channel: fn(_) -> {:ok, :c.pid(0, 255, 0)} end
      ]}
    ]) do
      assert {_, _} = ChannelAuthenticator.create_channel("App1", "User1")
    end
  end

  test "Should verify creds" do
    with_mocks([
      {ChannelSupervisor, [], [
        start_channel: fn(_) -> {:ok, :c.pid(0, 255, 0)} end,
        register_channel: fn(_) -> {:ok, :c.pid(0, 255, 0)} end
      ]}
    ]) do
      {ref , secret} = ChannelAuthenticator.create_channel("App1", "User1")
      assert {:ok, "App1", "User1"} == ChannelAuthenticator.authorize_channel(ref, secret)
    end
  end

  test "Should fail verify creds" do
    assert :unauthorized == ChannelAuthenticator.authorize_channel("some ref", "x")
  end

end
