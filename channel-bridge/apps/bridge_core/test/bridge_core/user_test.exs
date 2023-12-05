defmodule BridgeCore.UserTest do
  use ExUnit.Case

  alias BridgeCore.User

  @moduletag :capture_log

  # setup do
  #   test_request =
  #     ChannelRequest.new(
  #       %{
  #         "user-id" => "CC1989637100",
  #         "application-id" => "abc321"
  #       },
  #       nil,
  #       %{
  #         "channelAlias" => "my-alias"
  #       },
  #       nil
  #     )

  #   on_exit(fn ->
  #     Application.delete_env(:channel_bridge, :request_user_identifier)
  #   end)

  #   {:ok, init_args: %{request: test_request}}
  # end

  test "Should build new user" do
    user = User.new("abc321")
    assert %User{} = User.new(nil)
    assert user != nil
    assert user.id == "abc321"
  end

end
