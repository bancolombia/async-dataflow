Code.compiler_options(ignore_module_conflict: true)

defmodule ChannelSenderEx.Core.HeadlessChannelOperationsTest do
  use ExUnit.Case, async: true
  import Mock

  alias ChannelSenderEx.Core.ChannelWorker
  alias ChannelSenderEx.Core.ChannelIDGenerator
  alias ChannelSenderEx.Core.HeadlessChannelOperations
  alias ChannelSenderEx.Core.RulesProvider.Helper

  @moduletag :capture_log

  setup_all do
    Application.put_env(:channel_sender_ex, :secret_base, {
        "aV4ZPOf7T7HX6GvbhwyBlDM8B9jfeiwi+9qkBnjXxUZXqAeTrehojWKHkV3U0kGc",
        "socket auth"
    })

    Application.ensure_all_started(:plug_crypto)
    Helper.compile(:channel_sender_ex)

    :poolboy.start_link([
      name: {:local, :channel_worker},
      worker_module: ChannelSenderEx.Core.ChannelWorker,
      size: 5,
      max_overflow: 10
    ])

    :ok
  end

  setup do

    Application.put_env(:channel_sender_ex, :max_unacknowledged_retries, 3)
    Helper.compile(:channel_sender_ex)

    on_exit(fn ->
      Application.delete_env(:channel_sender_ex, :max_unacknowledged_retries)
      Helper.compile(:channel_sender_ex)
    end)

    :ok
  end

  test "Should create a channel" do
    with_mocks([
      {ChannelWorker, [], [
        save_channel: fn(_, _) -> :ok end
      ]}
    ]) do
      assert {:ok, _, _} = HeadlessChannelOperations.create_channel(%{"application_ref" => "a", "user_ref" => "b"})
    end
  end

  test "Should delete channel" do
    with_mocks([
      {ChannelWorker, [], [
        delete_channel: fn(_) -> :ok end
      ]}
    ]) do
      assert :ok = HeadlessChannelOperations.delete_channel("xyz")
    end
  end

  test "Should process on_connect to validate a channel exists" do
    with_mocks([
      {ChannelWorker, [], [
        get_channel: fn(_) -> {:ok, "my.connection"} end,
        save_socket: fn(_, _) -> :ok end
      ]}
    ]) do
      assert {:ok, "OK"} = HeadlessChannelOperations.on_connect("ch1", "my.connection")
      assert_called ChannelWorker.get_channel(:_)
      assert_called ChannelWorker.save_socket(:_, :_)
    end
  end

  test "Should process on_connect with fail to validate channel existence" do
    with_mocks([
      {ChannelWorker, [], [
        get_channel: fn(_) -> {:error, :not_found} end,
        disconnect_raw_socket: fn(_, _) -> :ok end
      ]}
    ]) do
      assert {:error, "3008"} = HeadlessChannelOperations.on_connect("ch1", "my.connection")
      Process.sleep(100)
      assert_called ChannelWorker.get_channel(:_)
      assert_called ChannelWorker.disconnect_raw_socket(:_, :_)
    end
  end

  test "Should process on_message to authenticate a channel" do

    channel_ref = ChannelIDGenerator.generate_channel_id("a", "b")
    secret = ChannelIDGenerator.generate_token(channel_ref, "a", "b")
    msg = %{"payload" => "Auth::" <> secret}
    connection_id = "my.connection"

    with_mocks([
      {ChannelWorker, [], [
        get_socket: fn(_) -> {:ok, channel_ref} end,
        save_socket: fn(_ref, _socket) -> :ok end,
        disconnect_socket: fn(_) -> :ok end
      ]}
    ]) do
      assert {:ok, "[\"\",\"\",\"AuthOk\",\"\"]"} = HeadlessChannelOperations.on_message(msg, connection_id)
      Process.sleep(100)
      assert_called ChannelWorker.get_socket(:_)
      assert_called ChannelWorker.save_socket(:_, :_)
      assert_not_called ChannelWorker.disconnect_socket(:_)
    end
  end

  test "Should process on_message and fail to authenticate a channel" do
    channel_ref = ChannelIDGenerator.generate_channel_id("a", "b")
    secret = ChannelIDGenerator.generate_token(channel_ref, "a", "b")
    msg = %{"payload" => "Auth::" <> secret}
    connection_id = "my.connection"

    with_mocks([
      {ChannelWorker, [], [
        get_socket: fn(_) -> {:error, :not_found} end,
        save_socket: fn(_ref, _socket) -> :ok end,
        disconnect_socket: fn(_) -> :ok end
      ]}
    ]) do
      assert {:unauthorized, "[\"\",\"\",\"AuthFailed\",\"\"]"} = HeadlessChannelOperations.on_message(msg, connection_id)
      Process.sleep(100)
      assert_called ChannelWorker.get_socket(:_)
      assert_not_called ChannelWorker.save_socket(:_, :_)
      assert_called ChannelWorker.disconnect_socket(:_)
    end
  end

  test "Should process on_message and handle ack" do
    msg = %{"payload" => "Ack::abc"}
    connection_id = "my.connection"

    with_mocks([
      {ChannelWorker, [], [
        ack_message: fn(_socket, _connection) -> :ok end,
      ]}
    ]) do
      assert {:ok, ""} = HeadlessChannelOperations.on_message(msg, connection_id)
      Process.sleep(100)
      assert_called ChannelWorker.ack_message(:_, :_)
    end
  end

  test "Should process on_message and handle heartbeat" do
    msg = %{"payload" => "hb::1"}
    connection_id = "my.connection"
    assert {:ok, "[\"\",1,\":hb\",\"\"]"} = HeadlessChannelOperations.on_message(msg, connection_id)
  end

  test "Should process on_message and handle any other message" do
    msg = %{"payload" => "foo"}
    connection_id = "my.connection"
    assert {:ok, "[\"\",\"\",\"9999\",\"\"]"} = HeadlessChannelOperations.on_message(msg, connection_id)
  end

  test "Should process on_disconnect" do
    connection_id = "my.connection"
    with_mocks([
      {ChannelWorker, [], [
        disconnect_socket: fn(_socket) -> :ok end,
      ]}
    ]) do
      assert :ok = HeadlessChannelOperations.on_disconnect(connection_id)
      assert_called ChannelWorker.disconnect_socket(:_)
    end
  end

end
