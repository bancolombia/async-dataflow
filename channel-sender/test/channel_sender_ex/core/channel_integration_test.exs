defmodule ChannelSenderEx.Core.ChannelIntegrationTest do
  use ExUnit.Case

  alias ChannelSenderEx.Core.RulesProvider.Helper
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
  alias ChannelSenderEx.Core.{Channel, ChannelRegistry, ChannelSupervisor, ProtocolMessage}
  alias ChannelSenderEx.Core.PubSub.PubSubCore
  alias ChannelSenderEx.Transport.EntryPoint

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

    {:ok, _} = Application.ensure_all_started(:cowboy)
    {:ok, _} = Application.ensure_all_started(:gun)
    {:ok, _} = Application.ensure_all_started(:plug_crypto)
    Helper.compile(:channel_sender_ex)

    ext_message = %{
      message_id: "id_msg0001",
      correlation_id: "1111",
      message_data: "Some_messageData",
      event_name: "event.example"
    }

    {:ok, pid_registry} = Horde.Registry.start_link(name: ChannelRegistry, keys: :unique)

    {:ok, pid_supervisor} =
      Horde.DynamicSupervisor.start_link(name: ChannelSupervisor, strategy: :one_for_one)

    on_exit(fn ->
      true = Process.exit(pid_registry, :normal)
      true = Process.exit(pid_supervisor, :normal)
      Application.delete_env(:channel_sender_ex, :accept_channel_reply_timeout)
      Application.delete_env(:channel_sender_ex, :on_connected_channel_reply_timeout)
      IO.puts("Supervisor and Registry was terminated")
    end)

    message = ProtocolMessage.to_protocol_message(ext_message)
    {:ok, ext_message: ext_message, message: message}
  end

  setup do
    [ok: _] = EntryPoint.start(0)
    port = :ranch.get_port(:external_server)

    on_exit(fn ->
      Application.delete_env(:channel_sender_ex, :channel_shutdown_on_clean_close)
      Application.delete_env(:channel_sender_ex, :channel_shutdown_on_disconnection)
      :ok = :cowboy.stop_listener(:external_server)
    end)

    {channel, secret} = ChannelAuthenticator.create_channel("App1", "User1234")
    {:ok, port: port, channel: channel, secret: secret}
  end

  test "Should just connect", %{
    port: port,
    channel: channel,
    secret: secret
  } do

    {conn, _stream} = assert_connect_and_authenticate(port, channel, secret)
    :gun.close(conn)
    Process.sleep(100)
  end

  test "Should handle re-creation of a process that already exists", %{
    port: port,
    channel: channel,
    secret: secret
  } do

    {:ok, pid} = ChannelSupervisor.start_channel({channel, "app", "user"})
    assert is_pid(pid)

  end

  test "Should change channel state to waiting when connection closes", %{
    port: port,
    channel: channel,
    secret: secret
  } do
    {conn, stream} = assert_connect_and_authenticate(port, channel, secret)
    assert {:accepted_connected, _, _} = deliver_message(channel)
    assert_receive {:gun_ws, ^conn, ^stream, {:text, _data_string}}
    :gun.close(conn)
    Process.sleep(100)
    assert {:accepted_waiting, _, _} = deliver_message(channel)
  end

  test "Should do no waiting when connection closes clean", %{
    port: port,
    channel: channel,
    secret: secret
  } do
    Helper.compile(:channel_sender_ex, channel_shutdown_on_clean_close: 0)
    Helper.compile(:channel_sender_ex, channel_shutdown_on_disconnection: 0)
    {conn, stream} = assert_connect_and_authenticate(port, channel, secret)
    assert {:accepted_connected, _, _} = deliver_message(channel)
    assert_receive {:gun_ws, ^conn, ^stream, {:text, _data_string}}

    channel_pid = ChannelRegistry.lookup_channel_addr(channel)
    :gun.close(conn)

    Process.sleep(500)
    assert Process.alive?(channel_pid) == false

    on_exit(fn ->
      Application.delete_env(:channel_sender_ex, :channel_shutdown_on_clean_close)
      Application.delete_env(:channel_sender_ex, :channel_shutdown_on_disconnection)
      Helper.compile(:channel_sender_ex)
    end)
  end

  test "Should not restart channel when terminated normal (Waiting timeout)" do
    Helper.compile(:channel_sender_ex, channel_shutdown_on_disconnection: 1)

    {channel, _secret} = ChannelAuthenticator.create_channel("App1", "User1234")
    channel_pid = ChannelRegistry.lookup_channel_addr(channel)

    ref = Process.monitor(channel_pid)
    assert_receive {:DOWN, ^ref, :process, ^channel_pid, :normal}, 1200
    Process.sleep(300)

    assert :noproc == ChannelRegistry.lookup_channel_addr(channel)
    Helper.compile(:channel_sender_ex)
  end

  test "Should send pending messages to twin process when terminated by supervisor merge (name conflict)" do
    channel_args = {"channel_ref", "application", "user_ref"}
    {:ok, _} = Horde.DynamicSupervisor.start_link(name: :sup1, strategy: :one_for_one)
    {:ok, _} = Horde.DynamicSupervisor.start_link(name: :sup2, strategy: :one_for_one)
    {:ok, _} = Horde.Registry.start_link(name: :reg1, keys: :unique)
    {:ok, _} = Horde.Registry.start_link(name: :reg2, keys: :unique)

    {:ok, pid1} = Horde.DynamicSupervisor.start_child(:sup1,
      ChannelSupervisor.channel_child_spec(channel_args, ChannelRegistry.via_tuple("channel_ref", :reg1)))
    {:ok, pid2} = Horde.DynamicSupervisor.start_child(:sup2,
      ChannelSupervisor.channel_child_spec(channel_args, ChannelRegistry.via_tuple("channel_ref", :reg2)))

    {_, msg1} = build_message("42")
    {_, msg2} = build_message("82")

    Channel.deliver_message(pid1, msg1)
    Channel.deliver_message(pid2, msg2)
    Process.monitor(pid1)
    Process.monitor(pid2)
    Horde.Cluster.set_members(:sup1, [:sup1, :sup2])
    Horde.Cluster.set_members(:reg1, [:reg1, :reg2])

    assert_receive {:DOWN, _ref, :process, channel_pid, _} when channel_pid in [pid1, pid2]

    assert [{pid, _}] = Horde.Registry.lookup(ChannelRegistry.via_tuple("channel_ref", :reg1))

    {_, %{pending_sending: {pending_msg, _}}} = :sys.get_state(pid)

    assert Map.get(pending_msg, "42") == msg1
    assert Map.get(pending_msg, "82") == msg2
  end

  test "Should send pending messages to twin process when terminated by supervisor merge (name conflict) II" do
    channel_args = {"channel_ref", "application", "user_ref"}
    {:ok, _} = Horde.DynamicSupervisor.start_link(name: :sup1, strategy: :one_for_one)
    {:ok, _} = Horde.DynamicSupervisor.start_link(name: :sup2, strategy: :one_for_one)
    {:ok, _} = Horde.Registry.start_link(name: :reg1, keys: :unique)
    {:ok, _} = Horde.Registry.start_link(name: :reg2, keys: :unique)

    {:ok, pid1} = Horde.DynamicSupervisor.start_child(:sup1,
      ChannelSupervisor.channel_child_spec(channel_args, ChannelRegistry.via_tuple("channel_ref", :reg1)))
    {:ok, pid2} = Horde.DynamicSupervisor.start_child(:sup2,
      ChannelSupervisor.channel_child_spec(channel_args, ChannelRegistry.via_tuple("channel_ref", :reg2)))

    send(pid1, {:socket_connected, self()})
    send(pid2, {:socket_connected, self()})

    {_, msg1} = build_message("42")
    {_, msg2} = build_message("82")

    Channel.deliver_message(pid1, msg1)
    Channel.deliver_message(pid2, msg2)

    Process.monitor(pid1)
    Process.monitor(pid2)

    Horde.Cluster.set_members(:sup1, [:sup1, :sup2])
    Horde.Cluster.set_members(:reg1, [:reg1, :reg2])

    assert_receive {:DOWN, _ref, :process, channel_pid, _} when channel_pid in [pid1, pid2]

    assert [{pid, _}] = Horde.Registry.lookup(ChannelRegistry.via_tuple("channel_ref", :reg1))

    {_, %{pending_sending: {pending_msg, _}}} = :sys.get_state(pid)

    assert Map.get(pending_msg, "42") == msg1
    assert Map.get(pending_msg, "82") == msg2
  end

  test "Should not fail when other socket is open and tied to an existing and open channel process", %{
    port: port,
    channel: channel,
    secret: secret
  } do
    {conn, stream} = assert_connect_and_authenticate(port, channel, secret)

    # try to open a new socket connection and link it to the same channel
    {conn2, stream} = assert_connect_and_authenticate(port, channel, secret)

    # receive the close message from the new connection
    assert_receive {:gun_ws, ^conn, _, {:close, 1001, "3009"}}, 500
    assert_receive {:gun_down, ^conn, :ws, :closed, [], []}, 500

    :gun.close(conn2)
  end

  test "Should supervisor re-create channel process when exits abnormally", %{
    port: port,
    channel: channel,
    secret: secret
  } do
    {conn, stream} = assert_connect_and_authenticate(port, channel, secret)

    channel_pid = ChannelRegistry.lookup_channel_addr(channel)
    assert is_pid(channel_pid)
    assert Process.alive?(channel_pid)

    # terminate channel process
    Process.exit(channel_pid, :kill)
    Process.sleep(100)

    # verify new process
    channel_pid2 = ChannelRegistry.lookup_channel_addr(channel)
    assert is_pid(channel_pid2)
    assert Process.alive?(channel_pid2)
    assert channel_pid != channel_pid2
  end

  test "Should channel ignore :shutdown signal", %{
    port: port,
    channel: channel,
    secret: secret
  } do
    {conn, stream} = assert_connect_and_authenticate(port, channel, secret)

    channel_pid = ChannelRegistry.lookup_channel_addr(channel)
    assert is_pid(channel_pid)
    assert Process.alive?(channel_pid)

    # try to terminate channel process
    Process.exit(channel_pid, :shutdown)
    Process.sleep(100)

    # verify process still alive
    assert Process.alive?(channel_pid)
  end

  defp deliver_message(channel, message_id \\ "42") do
    {data, message} = build_message(message_id)
    channel_response = PubSubCore.deliver_to_channel(channel, message)
    {channel_response, message_id, data}
  end

  defp build_message(message_id) do
    data = "MessageData12_3245rs42112aa" <> message_id
    message = ProtocolMessage.to_protocol_message(%{
      message_id: message_id,
      correlation_id: "",
      message_data: data,
      event_name: "event.test"
    })
    {data, message}
  end

  defp assert_connect_and_authenticate(port, channel, secret) do
    conn = connect(port, channel)
    assert_receive {:gun_upgrade, ^conn, stream, ["websocket"], _headers}, 500
    :gun.ws_send(conn, {:text, "Auth::#{secret}"})

    assert_receive {:gun_ws, ^conn, ^stream, {:text, data_string}}
    message = decode_message(data_string)
    assert "AuthOk" == ProtocolMessage.event_name(message)
    {conn, stream}
  end

  defp connect(port, channel) do
    {:ok, conn} = :gun.open(~c"127.0.0.1", port)
    {:ok, _} = :gun.await_up(conn)
    :gun.ws_upgrade(conn, "/ext/socket?channel=#{channel}")
    conn
  end

  @spec decode_message(String.t()) :: ProtocolMessage.t()
  defp decode_message(string_data) do
    socket_message = Jason.decode!(string_data)
    ProtocolMessage.from_socket_message(socket_message)
  end
end
