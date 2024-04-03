defmodule BridgeApi.Rest.ChannelRequestTest do
  use ExUnit.Case
  use Plug.Test
  import Mock

  alias BridgeApi.Rest.ChannelRequest

  @moduletag :capture_log

  test "should create new struct" do

    assert %BridgeApi.Rest.ChannelRequest{body: %{}, req_headers: %{}, req_params: %{}, token_claims: %{}}
       == ChannelRequest.new(%{}, %{}, %{}, %{})
  end

  test "should search channel alias in struct data" do
    sample_headers = %{"sub" => "value1"}
    ch_req = ChannelRequest.new(sample_headers, %{}, %{}, %{})
    assert ChannelRequest.extract_channel_alias(ch_req) == {:ok, "value1"}
  end

  test "should not find channel alias in struct data" do
    sample_headers = %{"xxxx" => "value1"}
    ch_req = ChannelRequest.new(sample_headers, %{}, %{}, %{})
    assert ChannelRequest.extract_channel_alias(ch_req) == {:error, :nosessionidfound}
  end

  test "should find app reference in struct data" do

    with_mocks([
      {BridgeHelperConfig, [],
       [
        get: fn _list, _default ->
          "$.req_headers['appid']"
         end
       ]}
    ]) do

      sample_headers = %{"appid" => "value1"}
      ch_req = ChannelRequest.new(sample_headers, %{}, %{}, %{})
      assert ChannelRequest.extract_application(ch_req) == {:ok, %BridgeCore.AppClient{channel_timeout: 420, id: "value1", name: ""}}

    end
  end

  test "should not find app reference in struct data, use default name" do

    with_mocks([
      {BridgeHelperConfig, [],
       [
        get: fn _list, _default ->
          "$.req_headers['appid']"
         end
       ]}
    ]) do

      ch_req = ChannelRequest.new(%{}, %{}, %{}, %{})
      assert ChannelRequest.extract_application(ch_req) == {:ok, %BridgeCore.AppClient{channel_timeout: 420, id: "default_app", name: ""}}

    end
  end

  test "should build app with fixed value from config" do

    with_mocks([
      {BridgeHelperConfig, [],
       [
        get: fn _list, _default ->
          "fooapp"
         end
       ]}
    ]) do

      ch_req = ChannelRequest.new(%{}, %{}, %{}, %{})
      assert ChannelRequest.extract_application(ch_req) == {:ok, %BridgeCore.AppClient{channel_timeout: 420, id: "fooapp", name: ""}}

    end
  end

  test "should find user reference in struct data" do

    with_mocks([
      {BridgeHelperConfig, [],
       [
        get: fn _list, _default ->
          "$.req_headers['userid']"
         end
       ]}
    ]) do

      sample_headers = %{"userid" => "value1"}
      ch_req = ChannelRequest.new(sample_headers, %{}, %{}, %{})
      assert ChannelRequest.extract_user_info(ch_req) == {:ok, %BridgeCore.User{id: "value1", name: nil}}

    end
  end

  test "should not find user reference in struct data, use default name" do

    with_mocks([
      {BridgeHelperConfig, [],
       [
        get: fn _list, _default ->
          "$.req_headers['userid']"
         end
       ]}
    ]) do

      ch_req = ChannelRequest.new(%{}, %{}, %{}, %{})
      assert ChannelRequest.extract_user_info(ch_req) == {:ok, %BridgeCore.User{id: "default_app", name: nil}}

    end
  end

  test "should build user with fixed value from config" do

    with_mocks([
      {BridgeHelperConfig, [],
       [
        get: fn _list, _default ->
          "foouser"
         end
       ]}
    ]) do

      ch_req = ChannelRequest.new(%{}, %{}, %{}, %{})
      assert ChannelRequest.extract_user_info(ch_req) == {:ok, %BridgeCore.User{id: "foouser", name: nil}}

    end
  end
end
