defmodule ChannelBridgeEx.Core.UserTest do
  use ExUnit.Case

  alias ChannelBridgeEx.Core.User
  alias ChannelBridgeEx.Core.Channel.ChannelRequest

  @moduletag :capture_log

  setup do
    test_request =
      ChannelRequest.new(
        %{
          "user-id" => "CC1989637100",
          "application-id" => "abc321"
        },
        nil,
        %{
          "channelAlias" => "my-alias"
        },
        nil
      )

    on_exit(fn ->
      Application.delete_env(:channel_bridge_ex, :request_user_identifier)
    end)

    {:ok, init_args: %{request: test_request}}
  end

  test "Should build new user" do
    user = User.new("abc321")
    assert %User{} = User.new(nil)
    assert user != nil
    assert user.id == "abc321"
  end

  test "Should extract user from ch request", %{init_args: init_args} do
    {:ok, user} = User.from_ch_request(init_args.request)
    assert user != nil
    assert "CC1989637100" == user.id
  end

  test "Should extract a default user from ch request", %{init_args: init_args} do
    Application.put_env(:channel_bridge_ex, :request_user_identifier, "$.req_headers.xxx")
    {:ok, user} = User.from_ch_request(init_args.request)
    assert user != nil
    assert "default_user_" == String.slice(user.id, 0..12)
  end
end
