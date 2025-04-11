# Code.compiler_options(ignore_module_conflict: true)

defmodule ChannelSenderEx.Core.HeadlessChannelOperationsTest do
  use ExUnit.Case, async: false
  import Mock

  alias ChannelSenderEx.Core.ChannelIDGenerator
  alias ChannelSenderEx.Core.HeadlessChannelOperations
  alias ChannelSenderEx.Core.RulesProvider.Helper
  alias ChannelSenderEx.Persistence.ChannelPersistence
  alias ChannelSenderEx.Adapter.WsConnections

  @moduletag :capture_log

  setup_all do
    Application.put_env(:channel_sender_ex, :secret_base, {
        "aV4ZPOf7T7HX6GvbhwyBlDM8B9jfeiwi+9qkBnjXxUZXqAeTrehojWKHkV3U0kGc",
        "socket auth"
    })
    Application.put_env(:channel_sender_ex, :max_age, 1)

    Application.ensure_all_started(:plug_crypto)
    Helper.compile(:channel_sender_ex)

    :poolboy.start_link([
      name: {:local, :channel_worker},
      worker_module: ChannelSenderEx.Core.ChannelWorker,
      size: 5,
      max_overflow: 10
    ])

    on_exit(fn ->
      # Application.delete_env(:channel_sender_ex, :max_unacknowledged_retries)
      Application.delete_env(:channel_sender_ex, :max_age)
      Helper.compile(:channel_sender_ex)
    end)

    :ok
  end

  # setup do
  #   Application.put_env(:channel_sender_ex, :max_unacknowledged_retries, 3)
  #   Application.put_env(:channel_sender_ex, :max_age, 1)
  #   Helper.compile(:channel_sender_ex)

  #   on_exit(fn ->
  #     Application.delete_env(:channel_sender_ex, :max_unacknowledged_retries)
  #     Application.delete_env(:channel_sender_ex, :max_age)
  #     Helper.compile(:channel_sender_ex)
  #   end)

  #   :ok
  # end

  test "Should create a channel" do
    with_mocks([
      {ChannelPersistence, [], [
        save_channel: fn(_, _) -> :ok end
      ]}
    ]) do
      assert {:ok, _, _} = HeadlessChannelOperations.create_channel(%{"application_ref" => "a", "user_ref" => "b"})
    end
  end

  test "Should delete channel" do
    with_mocks([
      {ChannelPersistence, [], [
        delete_channel: fn(_) -> :ok end,
        save_channel: fn(_, _) -> :ok end
      ]}
    ]) do
      assert :ok = HeadlessChannelOperations.delete_channel("xyz")
    end
  end

  test "Should process on_connect to validate a channel exists" do
    with_mocks([
      {ChannelPersistence, [], [
        get_channel: fn(_) -> {:ok, "my.connection555666"} end,
        save_socket: fn(_, _) -> :ok end,
        delete_socket: fn(_, _) -> :ok end,
        ack_message: fn(_, _) -> :ok end
      ]}
    ]) do
      assert {:ok, "OK"} = HeadlessChannelOperations.on_connect("ch1", "my.connection555666")
      Process.sleep(100)
      assert_called ChannelPersistence.get_channel(:_)
      assert_called ChannelPersistence.save_socket(:_, :_)
    end
  end

  test "Should process on_connect with fail to validate channel existence" do
    with_mocks([
      {ChannelPersistence, [], [
        get_channel: fn(_) -> {:error, :not_found} end,
        save_socket: fn(_, _) -> :ok end,
        delete_socket: fn(_, _) -> :ok end
      ]},
      {WsConnections, [], [
        send_data: fn(_, _) -> :ok end,
        close: fn(_) -> :ok end,
      ]}
    ]) do
      assert {:error, "3008"} = HeadlessChannelOperations.on_connect("ch2", "my.connection")
      Process.sleep(100)
      assert_called ChannelPersistence.get_channel(:_)
      assert_called WsConnections.send_data(:_, :_)
      # assert_called WsConnections.close(:_)
    end
  end

  test "Should process on_message to authenticate a channel" do

    channel_ref = ChannelIDGenerator.generate_channel_id("a", "b")
    secret = ChannelIDGenerator.generate_token(channel_ref, "a", "b")
    msg = %{"payload" => "Auth::" <> secret}
    connection_id = "my.connection"

    with_mocks([
      {ChannelPersistence, [], [
        get_socket: fn(_) -> {:ok, channel_ref} end,
        save_socket: fn(_ref, _socket) -> :ok end,
        delete_socket: fn(_, _) -> :ok end,
        save_channel: fn(_, _) -> :ok end
      ]},
      {WsConnections, [], [
        close: fn(_) -> :ok end,
      ]}
    ]) do
      assert {:ok, "[\"\",\"\",\"AuthOk\",\"\"]"} = HeadlessChannelOperations.on_message(msg, connection_id)
      Process.sleep(100)
      assert_called ChannelPersistence.get_socket(:_)
      assert_called ChannelPersistence.save_socket(:_, :_)
    end
  end

  test "Should process on_message and fail to authenticate a channel" do
    channel_ref = ChannelIDGenerator.generate_channel_id("a", "b")
    secret = ChannelIDGenerator.generate_token(channel_ref, "a", "b")
    msg = %{"payload" => "Auth::" <> secret}
    connection_id = "my.connection2346778"

    with_mocks([
      {ChannelPersistence, [], [
        get_socket: fn(_) -> {:error, :not_found} end,
        save_socket: fn(_ref, _socket) -> :ok end,
        delete_socket: fn(_ref, _socket) -> :ok end,
        save_channel: fn(_ref, _socket) -> :ok end,
      ]},
      {WsConnections, [], [
        send_data: fn(_, _) -> :ok end,
        close: fn(_) -> :ok end,
      ]}
    ]) do
      assert {:unauthorized, "[\"\",\"\",\"AuthFailed\",\"\"]"} = HeadlessChannelOperations.on_message(msg, connection_id)
      Process.sleep(100)
      assert_called ChannelPersistence.get_socket(:_)
      assert_not_called ChannelPersistence.save_socket(:_, :_)
      # assert_called WsConnections.close(:_)
    end
  end

  test "Should process on_message and handle renew token" do
    channel_ref = ChannelIDGenerator.generate_channel_id("a", "b")
    secret = ChannelIDGenerator.generate_token(channel_ref, "a", "b")

    msg = %{"payload" => "n_token::" <> secret}
    connection_id = "my.connection0978"

    with_mocks([
      {ChannelPersistence, [], [
        get_socket: fn(_) -> {:ok, channel_ref} end,
        save_socket: fn(_ref, _socket) -> :ok end,
        delete_socket: fn(_, _) -> :ok end,
        save_channel: fn(_, _) -> :ok end,
      ]},
      {WsConnections, [], [
        close: fn(_) -> :ok end,
      ]}
    ]) do
      {:ok, result} = HeadlessChannelOperations.on_message(msg, connection_id)
      assert ["", "", ":n_token", _secret] = Jason.decode!(result)
      assert_called ChannelPersistence.get_socket(:_)
      assert_called ChannelPersistence.save_socket(:_, :_)
    end
  end

  test "Should process on_message and handle failure to renew token" do
    channel_ref = ChannelIDGenerator.generate_channel_id("a", "b")
    secret = ChannelIDGenerator.generate_token(channel_ref, "a", "b")

    msg = %{"payload" => "n_token::" <> secret}
    connection_id = "my.connection23454"

    with_mocks([
      {ChannelPersistence, [], [
        get_socket: fn(_) ->
          Process.sleep(1100)
          {:ok, channel_ref}
        end,
        save_socket: fn(_ref, _socket) -> :ok end,
        delete_socket: fn(_) -> :ok end
      ]}
    ]) do
      {:ok, result} = HeadlessChannelOperations.on_message(msg, connection_id)
      assert ["", "", "AuthFailed", ""] = Jason.decode!(result)
      assert_called ChannelPersistence.get_socket(:_)
      assert_not_called ChannelPersistence.save_socket(:_, :_)
      # assert_called ChannelWorker.disconnect_socket(:_)
    end
  end

  test "Should process on_message and handle ack" do
    msg = %{"payload" => "Ack::abc"}
    connection_id = "my.connection56789887"

    with_mocks([
      {ChannelPersistence, [], [
        ack_message: fn(_socket, _connection) -> :ok end,
      ]}
    ]) do
      assert {:ok, "[\"\",\"\",\":Ack\",\"\"]"} = HeadlessChannelOperations.on_message(msg, connection_id)
      Process.sleep(100)
      assert_called ChannelPersistence.ack_message(:_, :_)
    end
  end

  test "Should process on_message and handle heartbeat" do
    msg = %{"payload" => "hb::1"}
    connection_id = "my.connection3456"
    assert {:ok, "[\"\",\"1\",\":hb\",\"\"]"} = HeadlessChannelOperations.on_message(msg, connection_id)
  end

  test "Should process on_message and handle any other message" do
    msg = %{"payload" => "foo"}
    connection_id = "my.connection234"
    assert {:ok, "[\"\",\"\",\"9999\",\"\"]"} = HeadlessChannelOperations.on_message(msg, connection_id)
  end

  test "Should process on_disconnect" do
    connection_id = "my.connection0009090"
    with_mocks([
      {ChannelPersistence, [], [
        get_socket: fn(_socket) -> {:ok, "ch098098"} end,
        delete_socket: fn(_, _) -> :ok end,
      ]},
      {WsConnections, [], [
        close: fn(_) -> :ok end,
      ]}
    ]) do
      assert :ok = HeadlessChannelOperations.on_disconnect(connection_id)
      Process.sleep(100)
      assert_called ChannelPersistence.delete_socket(:_, :_)
    end
  end

end
