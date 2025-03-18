defmodule ChannelSenderEx.Core.Security.ChannelAuthenticatorTest do
  use ExUnit.Case

  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
  alias ChannelSenderEx.Core.RulesProvider.Helper

  @moduletag :capture_log

  setup_all do
    Application.put_env(:channel_sender_ex, :secret_base, {
      "aV4ZPOf7T7HX6GvbhwyBlDM8B9jfeiwi+9qkBnjXxUZXqAeTrehojWKHkV3U0kGc",
      "socket auth"
    })
    Application.put_env(:channel_sender_ex, :channel_shutdown_tolerance, 100)
    Application.put_env(:channel_sender_ex, :max_age, 1)
    Helper.compile(:channel_sender_ex)

    {:ok, _} = Application.ensure_all_started(:plug_crypto)

    on_exit(fn ->
      Application.delete_env(:channel_sender_ex, :channel_shutdown_tolerance)
      Application.delete_env(:channel_sender_ex, :max_age)
      Helper.compile(:channel_sender_ex)
    end)

    :ok
  end

  test "Should create channel" do
    assert {_, _} = ChannelAuthenticator.create_channel_credentials("App1", "User1")
  end

  test "Should verify creds" do
    {ref , secret} = ChannelAuthenticator.create_channel_credentials("App1", "User1")
    assert {:ok, "App1", "User1"} == ChannelAuthenticator.authorize_channel(ref, secret)
  end

  test "Should renew creds" do
    {ref , secret} = ChannelAuthenticator.create_channel_credentials("App1", "User1")
    Process.sleep(100)
    {:ok, secret2} = ChannelAuthenticator.renew_channel_secret(ref, secret)
    assert secret != secret2
  end

  test "Should fail renew creds" do
    {ref , secret} = ChannelAuthenticator.create_channel_credentials("App1", "User1")
    Process.sleep(1500)
    assert :unauthorized = ChannelAuthenticator.renew_channel_secret(ref, secret)
  end


  test "Should fail verify creds" do
    assert :unauthorized == ChannelAuthenticator.authorize_channel("some ref", "x")
  end

end
