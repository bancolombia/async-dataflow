Code.compiler_options(ignore_module_conflict: true)

defmodule ChannelSenderEx.Core.ChannelTest do
  use ExUnit.Case

  alias ChannelSenderEx.Core.Channel
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.ChannelIDGenerator
  alias ChannelSenderEx.Core.RulesProvider.Helper

  @moduletag :capture_log

  setup_all do
    {:ok, _} = Application.ensure_all_started(:plug_crypto)
    Helper.compile(:channel_sender_ex)
    :ok
  end

  setup do
    app = "app23324"
    user_ref = "user234"
    channel_ref = ChannelIDGenerator.generate_channel_id(app, user_ref)

    {:ok,
     init_args: {channel_ref, app, user_ref},
     message: %{
       message_id: "32452",
       correlation_id: "1111",
       message_data: "Some_messageData",
       event_name: "event.example"
     }}
  end

  test "Should Send message when connected", %{init_args: init_args, message: message} do
    {:ok, pid} = start_channel_safe(init_args)
    :ok = Channel.socket_connected(pid, self())
    message_to_send = ProtocolMessage.to_protocol_message(message)
    :accepted_connected = Channel.deliver_message(pid, message_to_send)
    assert_receive {:deliver_msg, _from = {^pid, _ref}, ^message_to_send}
    Process.exit(pid, :kill)
  end

  test "On connect should deliver message", %{init_args: init_args, message: message} do
    {:ok, pid} = start_channel_safe(init_args)
    message_to_send = ProtocolMessage.to_protocol_message(message)
    :accepted_waiting = Channel.deliver_message(pid, message_to_send)
    refute_receive {_from = {^pid, _ref}, ^message_to_send}, 350
    :ok = Channel.socket_connected(pid, self())
    assert_receive {:deliver_msg, _from = {^pid, _ref}, ^message_to_send}
    Process.exit(pid, :kill)
  end

  test "Should re-deliver message when no ack", %{init_args: init_args, message: message} do
    {:ok, pid} = start_channel_safe(init_args)
    :ok = Channel.socket_connected(pid, self())
    message_to_send = ProtocolMessage.to_protocol_message(message)
    :accepted_connected = Channel.deliver_message(pid, message_to_send)
    assert_receive {:deliver_msg, _from = {^pid, _ref}, ^message_to_send}
    assert_receive {:deliver_msg, _from = {^pid, _ref}, ^message_to_send}, 200
    Process.exit(pid, :kill)
  end

  test "Should not re-deliver message ack is received", %{init_args: init_args, message: message} do
    {:ok, pid} = start_channel_safe(init_args)
    :ok = Channel.socket_connected(pid, self())
    message_to_send = ProtocolMessage.to_protocol_message(message)
    :accepted_connected = Channel.deliver_message(pid, message_to_send)
    assert_receive {:deliver_msg, _from = {^pid, ref}, ^message_to_send}
    Channel.notify_ack(pid, ref, message.message_id)
    refute_receive {:deliver_msg, _from = {^pid, _ref}, ^message_to_send}, 300
    Process.exit(pid, :kill)
  end

  test "Should send new token in correct interval", %{init_args: init_args = {channel, _, _}} do
    Helper.compile(:channel_sender_ex, max_age: 2)
    {:ok, pid} = start_channel_safe(init_args)
    :sys.trace(pid, true)
    :ok = Channel.socket_connected(pid, self())
    refute_receive {:deliver_msg, _from = {^pid, _}, {_, "", ":n_token", _token, _}}, 950
    assert_receive {:deliver_msg, _from = {^pid, ref}, {id, "", ":n_token", _token, _}}, 1100
    Channel.notify_ack(pid, ref, id)
    refute_receive {:deliver_msg, _from = {^pid, _}, {_, "", ":n_token", _token, _}}, 950
    assert_receive {:deliver_msg, _from = {^pid, ref}, {id, "", ":n_token", _token, _}}, 1100
    Channel.notify_ack(pid, ref, id)
    refute_receive {:deliver_msg, _from = {^pid, _}, {_, "", ":n_token", _token, _}}, 950
    assert_receive {:deliver_msg, _from = {^pid, ref}, {id, "", ":n_token", token, _}}, 1100
    Channel.notify_ack(pid, ref, id)

    assert {:ok, _app, _user} = ChannelIDGenerator.verify_token(channel, token)

    Process.exit(pid, :kill)
    Helper.compile(:channel_sender_ex)
  end

  test "Should not fail when multiples acks was received", %{
    init_args: init_args,
    message: message
  } do
    {:ok, pid} = start_channel_safe(init_args)
    :ok = Channel.socket_connected(pid, self())
    message_to_send = ProtocolMessage.to_protocol_message(message)
    :accepted_connected = Channel.deliver_message(pid, message_to_send)
    assert_receive {:deliver_msg, _from = {^pid, ref}, ^message_to_send}

    Channel.notify_ack(pid, ref, message.message_id)
    Process.sleep(70)
    Channel.notify_ack(pid, ref, message.message_id)
    Process.sleep(70)
    Channel.notify_ack(pid, ref, message.message_id)
    Process.sleep(70)

    refute_receive {:deliver_msg, _from = {^pid, _ref}, ^message_to_send}, 300

    :accepted_connected = Channel.deliver_message(pid, message_to_send)
    assert_receive {:deliver_msg, _from = {^pid, _ref}, ^message_to_send}

    Process.exit(pid, :kill)
  end

  test "Should cancel retries on late ack", %{init_args: init_args, message: message} do
    {:ok, pid} = start_channel_safe(init_args)
    :ok = Channel.socket_connected(pid, self())
    message_to_send = ProtocolMessage.to_protocol_message(message)
    :accepted_connected = Channel.deliver_message(pid, message_to_send)
    assert_receive {:deliver_msg, _from = {^pid, ref}, ^message_to_send}
    # Receive retry
    assert_receive {:deliver_msg, _from = {^pid, _ref}, ^message_to_send}, 150

    # Late ack
    Channel.notify_ack(pid, ref, message.message_id)

    # Assert cancel retries
    refute_receive {:deliver_msg, _from = {^pid, _ref}, ^message_to_send}, 400

    Process.exit(pid, :kill)
  end

  test "Should postpone redelivery when Channel state change to waiting (disconnected)", %{
    init_args: init_args,
    message: message
  } do
    proxy = proxy_process()
    {:ok, channel_pid} = start_channel_safe(init_args)
    #    :sys.trace(channel_pid, true)
    :ok = Channel.socket_connected(channel_pid, proxy)

    message_to_send = ProtocolMessage.to_protocol_message(message)
    assert :accepted_connected = Channel.deliver_message(channel_pid, message_to_send)
    assert_receive {:deliver_msg, _from = {^channel_pid, _ref}, ^message_to_send}

    send(proxy, :stop)
    refute_receive {:deliver_msg, _from = {^channel_pid, _ref}, ^message_to_send}, 350
    assert {:waiting, _data} = :sys.get_state(channel_pid)

    proxy = proxy_process()
    :ok = Channel.socket_connected(channel_pid, proxy)

    assert_receive {:deliver_msg, _from = {^channel_pid, _ref}, ^message_to_send}
    assert_receive {:deliver_msg, _from = {^channel_pid, _ref}, ^message_to_send}, 300

    send(proxy, :stop)
    Process.exit(channel_pid, :kill)
  end

  test "Should terminate channel when no socket connected (Waiting timeout)", %{
    init_args: init_args
  } do
    Helper.compile(:channel_sender_ex, max_age: 1)
    {:ok, channel_pid} = start_channel_safe(init_args)
    :sys.trace(channel_pid, true)
    assert Process.alive? channel_pid
    ref = Process.monitor(channel_pid)
    assert_receive {:DOWN, ^ref, :process, ^channel_pid, :normal}, 1200
    Helper.compile(:channel_sender_ex)
  end

  defp proxy_process() do
    pid = self()
    spawn(fn -> loop_and_resend(pid) end)
  end

  def loop_and_resend(target_pid) do
    receive do
      :stop ->
        nil

      any ->
        send(target_pid, any)
        loop_and_resend(target_pid)
    end
  end

  def start_channel_safe(args) do
    parent = self()
    ref = make_ref()

    spawn(fn ->
      Process.flag(:trap_exit, true)
      send(parent, {ref, Channel.start_link(args)})

      receive do
        z -> IO.inspect(z)
      end
    end)

    receive do
      {^ref, result} -> result
    after
      1000 -> :timeout
    end
  end
end
