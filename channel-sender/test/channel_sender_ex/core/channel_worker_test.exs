Code.compiler_options(ignore_module_conflict: true)

defmodule ChannelSenderEx.Core.ChannelWorkerTest do
  use ExUnit.Case, async: true
  import Mock

  alias ChannelSenderEx.Core.BoundedMap
  alias ChannelSenderEx.Core.ChannelWorker
  alias ChannelSenderEx.Core.Data
  alias ChannelSenderEx.Core.ChannelIDGenerator
  alias ChannelSenderEx.Core.RulesProvider.Helper
  alias ChannelSenderEx.Persistence.ChannelPersistence
  alias ChannelSenderEx.Core.MessageProcessSupervisor

  @moduletag :capture_log

  setup_all do
    Application.put_env(:channel_sender_ex,
    :accept_channel_reply_timeout,
    1000)

    Application.put_env(:channel_sender_ex,
      :on_connected_channel_reply_timeout,
      2000)

    Application.put_env(:channel_sender_ex, :channel_shutdown_on_clean_close, 900)
    Application.put_env(:channel_sender_ex, :channel_shutdown_on_disconnection, 900)
    Application.put_env(:channel_sender_ex, :secret_base, {
        "aV4ZPOf7T7HX6GvbhwyBlDM8B9jfeiwi+9qkBnjXxUZXqAeTrehojWKHkV3U0kGc",
        "socket auth"
    })

    {:ok, _} = Application.ensure_all_started(:plug_crypto)
    Helper.compile(:channel_sender_ex)

    {:ok, _} = :poolboy.start_link([
      name: {:local, :channel_worker},
      worker_module: ChannelSenderEx.Core.ChannelWorker,
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

    {channel_ref, app, user_ref, []} = init_args
    data = %Data{application: app, user_ref: user_ref, channel: channel_ref}

    with_mocks([
      {ChannelPersistence, [], [
        save_channel_data: fn(_) -> :ok end,
        get_channel_data: fn(_) -> {:ok, data} end
      ]}
    ]) do
      assert :ok = ChannelWorker.save_channel(data)
      {:ok, data2} = ChannelWorker.get_channel("channel_#{channel_ref}")
      assert data == data2
    end
  end

  test "Should save and read socket data", %{init_args: init_args} do

    {channel_ref, _app, _user_ref, []} = init_args

    with_mocks([
      {ChannelPersistence, [], [
        save_socket_data: fn(_ref, _conn_id) -> :ok end,
        get_channel_data: fn(_) -> {:ok, channel_ref} end
      ]}
    ]) do
      assert :ok = ChannelWorker.save_socket_data(channel_ref, "my.connection.id")
      {:ok, data} = ChannelWorker.get_channel("socket_my.connection.id")
      assert data == channel_ref
    end

  end

  test "Should delete channel data", %{init_args: init_args} do

    {channel_ref, app, user_ref, []} = init_args
    data = %Data{application: app, user_ref: user_ref, channel: channel_ref}

    with_mocks([
      {ChannelPersistence, [], [
        save_channel_data: fn(_) -> :ok end,
        get_channel_data: fn(_) -> {:ok, data} end,
        delete_channel_data: fn(_) -> :ok end
      ]}
    ]) do
      assert :ok = ChannelWorker.save_channel(data)
      Process.sleep(10)
      assert :ok = ChannelWorker.delete_channel("channel_#{channel_ref}")
      Process.sleep(10)
      assert_called ChannelPersistence.delete_channel_data(:_)
    end
  end

  test "Should update data with socket id", %{init_args: init_args} do

    {channel_ref, app, user_ref, []} = init_args
    data = %Data{application: app, user_ref: user_ref, channel: channel_ref}

    with_mocks([
      {ChannelPersistence, [], [
        save_channel_data: fn(data) ->
          assert data.socket == "my.connection.id"
          :ok
        end,
        get_channel_data: fn(_) -> {:ok, data} end
      ]}
    ]) do

      assert :ok = ChannelWorker.accept_socket(channel_ref, "my.connection.id")
      Process.sleep(10)

      assert_called ChannelPersistence.save_channel_data(:_)
    end
  end

  test "Should update data removing socket id", %{init_args: init_args} do

    {channel_ref, app, user_ref, []} = init_args
    data = %Data{application: app, user_ref: user_ref, channel: channel_ref}

    with_mocks([
      {ChannelPersistence, [], [
        save_channel_data: fn(data) ->
          assert data.socket == nil
          :ok
        end,
        delete_channel_data: fn(_) -> :ok end,
        get_channel_data: fn(ref) ->
          case String.starts_with?(ref, "channel_") do
            true -> {:ok, data}
            false -> {:ok, channel_ref}
          end
        end
      ]}
    ]) do

      assert :ok = ChannelWorker.disconnect_socket("my.connection.id")
      Process.sleep(10)

      assert_called ChannelPersistence.delete_channel_data("socket_my.connection.id")
    end
  end

  test "Should process ack operation", %{init_args: init_args, message: message} do

    {channel_ref, app, user_ref, []} = init_args

    messages = BoundedMap.new()
    |> BoundedMap.put(Map.get(message, "message_id"), message)

    data = %Data{application: app, user_ref: user_ref, channel: channel_ref,
      pending: messages}

    with_mocks([
      {ChannelPersistence, [], [
        save_channel_data: fn(data_arg) ->
          assert {%{}, []} == data_arg.pending
          :ok
        end,
        get_channel_data: fn(ref) ->
          case String.starts_with?(ref, "channel_") do
            true -> {:ok, data}
            false -> {:ok, channel_ref}
          end
        end
      ]}
    ]) do

      assert :ok = ChannelWorker.ack_message("my.connection.id", "32452")
      Process.sleep(10)
      assert_called ChannelPersistence.save_channel_data(:_)
    end
  end

  test "Should process route message operation", %{init_args: init_args, message: message} do

    {channel_ref, app, user_ref, []} = init_args
    data = %Data{application: app, user_ref: user_ref, channel: channel_ref, socket: "my.connection.id"}

    with_mocks([
      {ChannelPersistence, [], [
        save_channel_data: fn(data_arg) ->
          assert BoundedMap.size(data_arg.pending) == 1
          :ok
        end,
        get_channel_data: fn(ref) ->
          case String.starts_with?(ref, "channel_") do
            true -> {:ok, data}
            false -> {:ok, channel_ref}
          end
        end]},
      {MessageProcessSupervisor, [], [start_message_process: fn(_) -> :ok end]}
    ]) do

      assert :ok = ChannelWorker.route_message(Map.put(message, "channel_ref", channel_ref))
      Process.sleep(10)
      assert_called ChannelPersistence.save_channel_data(:_)
      assert_called MessageProcessSupervisor.start_message_process(:_)
    end
  end


end
