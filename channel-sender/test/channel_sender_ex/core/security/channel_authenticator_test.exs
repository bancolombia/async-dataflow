defmodule ChannelSenderEx.Core.Security.ChannelAuthenticatorTest do
  use ExUnit.Case

  alias ChannelSenderEx.Core.ChannelRegistry
  alias ChannelSenderEx.Core.ChannelSupervisor
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator

  @moduletag :capture_log

  setup_all do
    Application.put_env(:channel_sender_ex, :secret_base, {
      "aV4ZPOf7T7HX6GvbhwyBlDM8B9jfeiwi+9qkBnjXxUZXqAeTrehojWKHkV3U0kGc",
      "socket auth"
    })
    Application.put_env(:channel_sender_ex, :channel_shutdown_tolerance, 100)
    Application.put_env(:channel_sender_ex, :max_age, 100)

    {:ok, _} = Application.ensure_all_started(:plug_crypto)

    ChannelRegistry.start_link([])
    ChannelSupervisor.start_link([])

    :ok
  end

  test "Should create channel" do
    assert {_, _} = ChannelAuthenticator.create_channel("App1", "User1")
  end

  test "Should verify creds" do
    {ref , secret} = ChannelAuthenticator.create_channel("App1", "User1")
    assert {:ok, "App1", "User1"} == ChannelAuthenticator.authorize_channel(ref, secret)
  end

  test "Should fail verify creds" do
    assert :unauthorized == ChannelAuthenticator.authorize_channel("some ref", "x")
  end

end
