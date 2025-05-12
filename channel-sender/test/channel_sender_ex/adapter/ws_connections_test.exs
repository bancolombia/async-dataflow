defmodule ChannelSenderEx.Adapter.WsConnectionsTest do
  use ExUnit.Case, async: true
  import Mock

  alias ChannelSenderEx.Adapter.WsConnections
  alias ChannelSenderEx.Core.RulesProvider.Helper

  @valid_connection_id "valid_connection_id"
  @invalid_connection_id ""
  @data "test_data"
  @endpoint "https://api.example.com/valid_connection_id"
  @headers [{"Content-Type", "application/json"}]

  setup_with_mocks([
    {ExAws.Config, [], [new: fn(_) -> %{access_key_id: "x", secret_access_key: "y", security_token: "z"} end]},
    {ExAws.STS, [], [get_session_token: fn -> nil end]},
    {ExAws, [], [request: fn(_,_) -> %{body: %{credentials: %{session_token: "x"}}} end]},
    {:aws_signature, [], [sign_v4: fn(_, _, _, _, _, _, _, _, _, _) -> {:ok, @headers} end]},
  ]) do

    # Application.put_env(:channel_sender_ex, :max_age, 10)
    # Helper.compile(:channel_sender_ex)

    # on_exit(fn ->
    #   Application.delete_env(:channel_sender_ex, :max_age)
    #   Helper.compile(:channel_sender_ex)
    # end)

    :ok
  end

  test "send_data/2 with valid connection_id" do
    with_mocks([
      {Finch, [], [
        build: fn (:post, _, _, _) -> :ok end,
        request: fn (_, _) -> {:ok, %Finch.Response{status: 200}} end
      ]}
    ]) do

      assert WsConnections.send_data(@valid_connection_id, @data) == :ok
    end
  end

  test "send_data/2 with invalid connection_id" do
    assert WsConnections.send_data(@invalid_connection_id, @data) == {:error, :invalid_connection_id}
  end

  test "close/1 with valid connection_id" do
    with_mocks([
      {Finch, [], [
        build: fn (:delete, _, _, _) -> :ok end,
        request: fn (_, _) -> {:ok, %Finch.Response{status: 200}} end
      ]}
    ]) do
      assert WsConnections.close(@valid_connection_id) == :ok
    end
  end

  test "close/1 with invalid connection_id" do
    assert WsConnections.close(@invalid_connection_id) == {:error, :invalid_connection_id}
  end
end
