Code.compiler_options(ignore_module_conflict: true)

defmodule ChannelSenderEx.Core.ChannelWorkerTest do
  use ExUnit.Case
  import Mock

  alias ChannelSenderEx.Adapter.WsConnections
  alias ChannelSenderEx.Core.ChannelWorker
  alias ChannelSenderEx.Core.ChannelIDGenerator
  alias ChannelSenderEx.Core.MessageProcessSupervisor
  alias ChannelSenderEx.Core.RulesProvider.Helper
  alias ChannelSenderEx.Persistence.ChannelPersistence

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
      worker_module: ChannelWorker,
      size: 5,
      max_overflow: 10
    ])

    :ok
  end

  setup do
    app = "app23324"
    user_ref = "user234"
    channel_ref = ChannelIDGenerator.generate_channel_id(app, user_ref)

    Application.put_env(:channel_sender_ex, :max_unacknowledged_retries, 3)
    Helper.compile(:channel_sender_ex)

    on_exit(fn ->
      Application.delete_env(:channel_sender_ex, :max_unacknowledged_retries)
      Helper.compile(:channel_sender_ex)
    end)

    {:ok,
     init_args: {channel_ref, app, user_ref, []},
     message: %{
       "message_id" => "32452",
       "correlation_id" => "1111",
       "message_data" => "Some_messageData",
       "event_name" => "event.example"
     }}
  end

  test "Should save and read channel data", %{init_args: init_args} do

    {channel_ref, _app, _user_ref, []} = init_args
    data = "my.connection.a"

    with_mocks([
      {ChannelPersistence, [], [
        save_channel: fn(_, _) -> :ok end,
        get_channel: fn(_) -> {:ok, data} end
      ]}
    ]) do
      assert :ok = ChannelWorker.save_channel(data)
      {:ok, data2} = ChannelWorker.get_channel(channel_ref)
      assert data == data2
    end
  end

  test "Should save and read socket data", %{init_args: init_args} do

    {channel_ref, _app, _user_ref, []} = init_args

    with_mocks([
      {ChannelPersistence, [], [
        save_socket: fn(_ref, _conn_id) -> :ok end,
        get_channel: fn(_) -> {:ok, channel_ref} end
      ]}
    ]) do
      assert :ok = ChannelWorker.save_socket(channel_ref, "my.connection.id")
      {:ok, data} = ChannelWorker.get_channel("socket_my.connection.id")
      assert data == channel_ref
    end

  end

  test "Should delete channel data", %{init_args: init_args} do

    {channel_ref, _app, _user_ref, []} = init_args
    data = "my.connection.b"

    with_mocks([
      {ChannelPersistence, [], [
        save_channel: fn(_, _) -> :ok end,
        get_channel: fn(_) -> {:ok, data} end,
        delete_channel: fn(_, _) -> :ok end
      ]}
    ]) do
      assert :ok = ChannelWorker.save_channel(data, "")
      Process.sleep(10)
      assert :ok = ChannelWorker.delete_channel(channel_ref)
      Process.sleep(10)
      assert_called ChannelPersistence.delete_channel(:_, :_)
    end
  end

  test "Should handle no data found when deleting channel data", %{init_args: init_args} do

    {channel_ref, _app, _user_ref, []} = init_args
    data = "my.connection.b"

    with_mocks([
      {ChannelPersistence, [], [
        save_channel: fn(_, _) -> :ok end,
        get_channel: fn(_) -> {:error, :not_found} end,
        delete_channel: fn(_, _) -> :ok end
      ]}
    ]) do
      assert :ok = ChannelWorker.save_channel(data, "")
      Process.sleep(10)
      assert :ok = ChannelWorker.delete_channel(channel_ref)
      Process.sleep(10)
      assert_not_called ChannelPersistence.delete_channel(:_, :_)
    end
  end

  test "Should update data with socket id", %{init_args: init_args} do

    {channel_ref, _app, _user_ref, []} = init_args
    data = "my.connection.id"

    with_mocks([
      {ChannelPersistence, [], [
        save_channel: fn(_ch, socket) ->
          assert socket == "my.connection.id"
          :ok
        end,
        get_channel: fn(_) -> {:ok, data} end,
      ]}
    ]) do

      assert :ok = ChannelWorker.accept_socket(channel_ref, "my.connection.id")
      Process.sleep(10)

      assert_called ChannelPersistence.save_channel(:_, :_)
    end
  end

  test "Should handle no channel found when trying to update data with socket id", %{init_args: init_args} do

    {channel_ref, _app, _user_ref, []} = init_args

    with_mocks([
      {ChannelPersistence, [], [
        save_channel: fn(_ch, socket) ->
          assert socket == "my.connection.id"
          :ok
        end,
        get_channel: fn(_) -> {:error, :not_found}  end,
      ]}
    ]) do

      assert :ok = ChannelWorker.accept_socket(channel_ref, "my.connection.id")
      Process.sleep(10)

      assert_not_called ChannelPersistence.save_channel(:_, :_)
    end
  end

  test "Should update data removing socket id", %{init_args: init_args} do

    {channel_ref, _app, _user_ref, []} = init_args

    with_mocks([
      {ChannelPersistence, [], [
        get_socket: fn(_) -> {:ok, channel_ref} end,
        delete_socket: fn(_, _) -> :ok end,
      ]}
    ]) do

      assert :ok = ChannelWorker.disconnect_socket("my.connection.id")
      Process.sleep(10)

      assert_called ChannelPersistence.delete_socket(:_, :_)
    end
  end

  test "Should handle no socket found when removing socket id" do

    with_mocks([
      {ChannelPersistence, [], [
        get_socket: fn(_) -> {:error, :not_found} end,
        delete_socket: fn(_, _) -> :ok end,
      ]}
    ]) do

      assert :ok = ChannelWorker.disconnect_socket("my.connection.id")
      Process.sleep(10)

      assert_not_called ChannelPersistence.delete_socket(:_, :_)
    end
  end

  test "Should process ack operation" do

    with_mocks([
      {ChannelPersistence, [], [
        delete_message: fn(_msg_id) ->
          :ok
        end
      ]}
    ]) do

      assert :ok = ChannelWorker.ack_message("conn.id", "32452")
      Process.sleep(10)
      assert_called ChannelPersistence.delete_message(:_)
    end
  end

  test "Should process route message operation", %{init_args: init_args, message: message} do

    {channel_ref, _app, _user_ref, []} = init_args

    with_mocks([
      {ChannelPersistence, [], [
        save_message: fn(_msg_id, _message) ->
          :ok
        end]},
      {MessageProcessSupervisor, [], [start_message_process: fn(_) -> :ok end]}
    ]) do

      assert :ok = ChannelWorker.route_message(Map.put(message, "channel_ref", channel_ref))
      Process.sleep(10)
      assert_called ChannelPersistence.save_message(:_, :_)
      assert_called MessageProcessSupervisor.start_message_process(:_)
    end
  end

  test "Should process raw closing disconnection" do

    with_mocks([
      {WsConnections, [], [
        send_data: fn(_, _) -> :ok end,
        close: fn(_) -> :ok end
      ]}
    ]) do
      assert :ok = ChannelWorker.disconnect_raw_socket("conn.id", "1000")
      Process.sleep(100)
      assert_called WsConnections.send_data(:_, :_)
      assert_called WsConnections.close(:_)
    end
  end

end
