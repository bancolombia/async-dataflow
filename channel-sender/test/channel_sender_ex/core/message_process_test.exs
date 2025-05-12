Code.compiler_options(ignore_module_conflict: true)

defmodule ChannelSenderEx.Core.MessageProcessTest do
  use ExUnit.Case
  import Mock

  alias ChannelSenderEx.Adapter.WsConnections
  alias ChannelSenderEx.Core.MessageProcess
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

    :ok
  end

  setup do

    Application.put_env(:channel_sender_ex, :initial_redelivery_time, 100)
    Application.put_env(:channel_sender_ex, :max_unacknowledged_retries, 3)
    Helper.compile(:channel_sender_ex)

    on_exit(fn ->
      Application.delete_env(:channel_sender_ex, :max_unacknowledged_retries)
      Application.delete_env(:channel_sender_ex, :initial_redelivery_time)
      Helper.compile(:channel_sender_ex)
    end)

    {:ok,
     message: %{
       "message_id" => "message1",
       "correlation_id" => UUID.uuid4(),
       "message_data" => "Some_messageData",
       "event_name" => "event.example"
     }}
  end

  test "Should start a message process, delivering message and stop after message not present",
    %{message: message} do

    socket = "my.connection.id"
    ref = "ref1"
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    with_mocks([
      {ChannelPersistence, [], [
        get_messages: fn(_channel_ref) ->
          count = Agent.get_and_update(counter, &{&1, &1 + 1})
          case count do
            0 -> {:ok, [socket, ["message1", Jason.encode!(message)]]}
            _ -> {:ok, [socket, nil]}
          end
        end,
        get_channel: fn(_) -> {:ok, ref} end
      ]},
      {WsConnections, [], [send_data: fn(_, _) -> :ok end]}
    ]) do

      {:ok, pid} = MessageProcess.start_link({"channel_ref"})
      monitor_ref = Process.monitor(pid)
      Process.sleep(1500)

      assert_called_at_least ChannelPersistence.get_messages(:_), 1
      assert_called_at_least WsConnections.send_data(:_, :_), 1

      # assert Message process ends
      assert_receive {:DOWN, ^monitor_ref, :process, ^pid, :normal}, 1000
    end
  end

  test "Should start a message process, delivering message and stop after retries exhausted",
    %{message: message} do

    socket = "my.connection.id"
    ref = "ref2"
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    with_mocks([
      {ChannelPersistence, [], [
        get_messages: fn(_channel_ref) ->
          count = Agent.get_and_update(counter, &{&1, &1 + 1})
          case count do
            _ -> {:ok, [socket, ["message1", Jason.encode!(message)]]}
          end
        end,
        get_channel: fn(_) -> {:ok, ref} end,
        delete_message: fn(_, _) -> :ok end
      ]},
      {WsConnections, [], [send_data: fn(_, _) -> :ok end]}
    ]) do

      {:ok, pid} = MessageProcess.start_link({"channel_ref"})
      monitor_ref = Process.monitor(pid)
      Process.sleep(1500)

      assert_called_at_least ChannelPersistence.get_messages(:_), 1
      assert_called_at_least WsConnections.send_data(:_, :_), 1
      assert_called_exactly ChannelPersistence.delete_message(:_, :_), 1

      # assert Message process ends
      assert_receive {:DOWN, ^monitor_ref, :process, ^pid, :normal}, 1000
    end
  end

  test "Should start a message process, and not delivering due to connection id not present",
    %{message: message} do

    ref = "ref3"
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    with_mocks([
      {ChannelPersistence, [], [
        get_messages: fn(_channel_ref) ->
          count = Agent.get_and_update(counter, &{&1, &1 + 1})
          case count do
            0 -> {:ok, [nil, ["message1", Jason.encode!(message)]]}
            _ -> {:ok, [nil, ["message1", Jason.encode!(message)]]}
          end
        end,
        delete_message: fn(_, _) -> :ok end,
        get_channel: fn(_) -> {:ok, ref} end
      ]},
      {WsConnections, [], [send_data: fn(_, _) -> :ok end]}
    ]) do

      {:ok, pid} = MessageProcess.start_link({"channel_ref"})
      monitor_ref = Process.monitor(pid)
      Process.sleep(1500)

      assert_called_at_least ChannelPersistence.get_messages(:_), 1
      # assert_called_exactly ChannelPersistence.delete_message(:_, :_), 1
      assert_called_exactly WsConnections.send_data(:_, :_), 0

      # assert Message process ends
      assert_receive {:DOWN, ^monitor_ref, :process, ^pid, :normal}, 1000
    end
  end

  test "Should start a message process, and not delivering due to wsconnections error",
    %{message: message} do
    socket = "my.connection.id4"
    ref = "ref4"
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    with_mocks([
      {ChannelPersistence, [], [
        get_messages: fn(_channel_ref) ->
          count = Agent.get_and_update(counter, &{&1, &1 + 1})
          case count do
            _ -> {:ok, [socket, ["message1", Jason.encode!(message)]]}
          end
        end,
        delete_message: fn(_, _) -> :ok end,
        get_channel: fn(_) -> {:ok, ref} end
      ]},
      {WsConnections, [], [send_data: fn(_, _) -> {:error, "dummy reason"}  end]}
    ]) do

      {:ok, pid} = MessageProcess.start_link({"channel_ref"})
      monitor_ref = Process.monitor(pid)
      Process.sleep(1500)

      assert_called_at_least ChannelPersistence.get_messages(:_), 1
      # assert_called_exactly ChannelPersistence.delete_message(:_, :_), 1
      assert_called_at_least WsConnections.send_data(:_, :_), 2

      # assert Message process ends
      assert_receive {:DOWN, ^monitor_ref, :process, ^pid, :normal}, 1000
    end
  end
end
