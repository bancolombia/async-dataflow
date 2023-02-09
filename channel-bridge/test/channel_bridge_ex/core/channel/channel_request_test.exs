defmodule ChannelBridgeEx.Core.Channel.ChannelRequestTest do
  use ExUnit.Case

  alias ChannelBridgeEx.Core.Channel.ChannelRequest

  @moduletag :capture_log

  setup do
    test_request =
      ChannelRequest.new(
        %{
          "application-id" => "abc123",
          "user-id" => "CC-123",
          "foo" => "CC",
          "bar" => "123",
          "session-tracker" => "af5bd2f6-505a-4b64-8cb8-7de564b3b8aa"
        },
        nil,
        nil,
        nil
      )

    on_exit(fn ->
      Application.delete_env(:channel_bridge_ex, :request_app_identifier)
      Application.delete_env(:channel_bridge_ex, :request_user_identifier)
    end)

    {:ok, init_args: %{request: test_request}}
  end

  test "Should build new channel request" do
    channel_request = ChannelRequest.new(%{}, %{}, %{}, %{})
    assert channel_request != nil
    assert channel_request.req_headers != nil
    assert channel_request.req_params != nil
    assert channel_request.body != nil
    assert channel_request.token_claims != nil

    assert channel_request == %ChannelRequest{
             req_headers: %{},
             req_params: %{},
             body: %{},
             token_claims: %{}
           }
  end

  test "Should extract channel alias", %{init_args: init_args} do
    {:ok, channel_alias} = ChannelRequest.extract_channel_alias(init_args.request)
    assert "af5bd2f6-505a-4b64-8cb8-7de564b3b8aa" == channel_alias
  end

  test "Should fail extract channel alias" do
    assert {:error, :nosessionidfound} =
             ChannelRequest.extract_channel_alias(ChannelRequest.new(%{}, %{}, %{}, %{}))
  end

  test "Should extract application id - fixed", %{init_args: init_args} do
    {:ok, app} = ChannelRequest.extract_application(init_args.request)
    assert "default_app" == app.id
  end

  test "Should extract application id - lookup", %{init_args: init_args} do
    Application.put_env(
      :channel_bridge_ex,
      :request_app_identifier,
      {:lookup, "$.req_headers['application-id']"}
    )

    {:ok, app} = ChannelRequest.extract_application(init_args.request)
    assert "abc123" == app.id
  end

  test "Should extract user info", %{init_args: init_args} do
    {:ok, user} = ChannelRequest.extract_user_info(init_args.request)
    assert "CC-123" == user.id
  end

  test "Should not find data to extract user info", %{init_args: init_args} do
    Application.put_env(
      :channel_bridge_ex,
      :request_user_identifier,
      ["$.req_headers.xxx", "$.req_headers.xxxx"]
    )

    {:ok, app} = ChannelRequest.extract_user_info(init_args.request)
    assert "undefined-undefined" == app.id
  end
end
