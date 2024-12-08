defmodule ChannelSenderEx.Transport.SocketIntegrationTest do
  use ExUnit.Case

  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Transport.EntryPoint
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.ChannelSupervisor
  alias ChannelSenderEx.Core.ChannelRegistry
  alias ChannelSenderEx.Core.RulesProvider.Helper
  alias ChannelSenderEx.Transport.Encoders.{BinaryEncoder, JsonEncoder}
  alias ChannelSenderEx.Core.ChannelIDGenerator
  alias ChannelSenderEx.Core.ChannelSupervisor

  @moduletag :capture_log

  @binary "binary_flow"
  @json "json_flow"

  setup_all do
    IO.puts("Starting Applications for Socket Test")

    Application.put_env(:channel_sender_ex,
      :accept_channel_reply_timeout,
      1000)

    Application.put_env(:channel_sender_ex,
      :on_connected_channel_reply_timeout,
      2000)

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
      Application.delete_env(:channel_sender_ex, :accept_channel_reply_timeout)
      Application.delete_env(:channel_sender_ex, :on_connected_channel_reply_timeout)
      Application.delete_env(:channel_sender_ex, :secret_base)
      true = Process.exit(pid_registry, :normal)
      true = Process.exit(pid_supervisor, :normal)
      IO.puts("Supervisor and Registry was terminated")
    end)

    message = ProtocolMessage.to_protocol_message(ext_message)
    {:ok, ext_message: ext_message, message: message}
  end

  setup do
    [ok: _] = EntryPoint.start(0)
    port = :ranch.get_port(:external_server)

    on_exit(fn ->
      :ok = :cowboy.stop_listener(:external_server)
    end)

    {channel, secret} = ChannelAuthenticator.create_channel("App1", "User1234")
    {:ok, port: port, channel: channel, secret: secret}
  end

  test "Should handle bad request", %{port: port, channel: channel} do
    conn = bad_connect(port, channel)
    assert_receive {:gun_response, ^conn, stream, :fin, 400, _}, 300

    :gun.close(conn)
  end

  test "Should connect to socket", %{port: port, channel: channel} do
    conn = connect(port, channel)
    assert_receive {:gun_upgrade, ^conn, stream, ["websocket"], _headers}, 300
    :gun.close(conn)
  end

  test "Should authenticate", %{port: port, channel: channel, secret: secret} do
    {conn, _stream} = assert_connect_and_authenticate(port, channel, secret)
    :gun.close(conn)
  end

  test "Should authenticate with binary protocol", %{port: port, channel: channel, secret: secret} do
    {conn, stream} = assert_connect_and_authenticate(port, channel, secret, @binary)
    :gun.close(conn)
  end

  test "Should close on authentication fail", %{port: port, channel: channel, secret: secret} do
    conn = connect(port, channel)
    assert_receive {:gun_upgrade, ^conn, stream, ["websocket"], _headers}
    :gun.ws_send(conn, {:text, "Auth::#{secret}Invalid"})
    assert_receive {:gun_ws, ^conn, ^stream, {:close, 1008, "Invalid token for channel"}}
    assert_receive {:gun_down, ^conn, :ws, :closed, [], []}
    refute_receive {:gun_up, _conn, _}
    :gun.close(conn)
  end

  test "Should reply heartbeat json protocol", params do
    assert {:text, _txt} = assert_reply_heartbeat(@json, params)
  end

  test "Should reply heartbeat with binary protocol", params do
    assert {:binary, _} = assert_reply_heartbeat(@binary, params)
  end

  test "Socket should close when no heartbeat was sent", %{
    port: port,
    channel: channel,
    secret: secret
  } do
    Helper.compile(:channel_sender_ex, socket_idle_timeout: 500)
    {conn, stream} = assert_connect_and_authenticate(port, channel, secret)

    refute_receive {:gun_ws, ^conn, ^stream, {:text, data_string}}
    assert_receive {:gun_ws, ^conn, ^stream, {:close, 1000, _reason}}, 1000

    :gun.close(conn)
    Helper.compile(:channel_sender_ex)
  end

  test "Should receive messages, json protocol", params do
    assert {:text, _} = assert_receive_message(@json, params)
  end

  test "Should receive messages, binary protocol", params do
    assert {:binary, _} = assert_receive_message(@binary, params)
  end

  test "Should continue to receive message when no ack was sent, json protocol", params do
    assert :text == assert_redelivery_no_ack(@json, params)
  end

  test "Should continue to receive message when no ack was sent, binary protocol", params do
    assert :binary == assert_redelivery_no_ack(@binary, params)
  end

  test "Should stop receiving same message after ack was sent, json protocol", params do
    assert_stop_redelivery(@json, params)
  end

  test "Should stop receiving same message after ack was sent, binary protocol", params do
    assert_stop_redelivery(@binary, params)
  end

  test "Should open socket with binary sub-protocol", %{
    port: port,
    channel: channel,
    secret: secret
  } do
    {conn, stream} = assert_connect_and_authenticate(port, channel, secret, @binary)

    {message_id, data} = deliver_message(channel)
    assert_receive {:gun_ws, ^conn, ^stream, data_bin = {:binary, _bin}}
    assert {^message_id, "", "event.test", ^data, _} = decode_message(data_bin)
    :gun.close(conn)
  end

  test "Should handle unallowed messages", %{
    port: port,
    channel: channel,
    secret: secret
  } do
    {conn, stream} = assert_connect_and_authenticate(port, channel, secret, @binary)

    :gun.ws_send(conn, {:text, "foo"})

    assert_receive {:gun_ws, ^conn, ^stream, {:text, "Echo: foo"}}
    :gun.close(conn)
  end

  test "Should open socket with json sub-protocol (explicit)", %{
    port: port,
    channel: channel,
    secret: secret
  } do
    conn_stream = assert_connect_and_authenticate(port, channel, secret, @json)
    assert {:text, _} = assert_receive_and_close(channel, conn_stream)
  end

  test "Should open socket with binary sub-protocol, (multi-options)", %{
    port: port,
    channel: channel,
    secret: secret
  } do
    conn_stream = assert_connect_and_authenticate(port, channel, secret, [@binary, @json])
    assert {:binary, _} = assert_receive_and_close(channel, conn_stream)
  end

  test "Should not connect to channel when not previoulsy registered", %{port: port} do
    {app_id, user_ref} = {"App1", "User1234"}
    channel_ref = ChannelIDGenerator.generate_channel_id(app_id, user_ref)
    channel_secret = ChannelIDGenerator.generate_token(channel_ref, app_id, user_ref)
    {conn, stream} = assert_reject(port, channel_ref, channel_secret)
  end


  test "Should reestablish Channel link when Channel gets restarted", %{
    port: port,
    channel: channel,
    secret: secret
  } do
    {conn, stream} = assert_connect_and_authenticate(port, channel, secret)
    {message_id, data} = deliver_message(channel)

    # fn  ->
    #   {conn, stream} = assert_connect_and_authenticate(port, channel, secret)
    #   :gun.close(conn)
    #   data
    # end

    assert_receive {:gun_ws, ^conn, ^stream, data_string = {type, _string}}
    assert {^message_id, "", "event.test", ^data, _} = decode_message(data_string)

    ch_pid = ChannelRegistry.lookup_channel_addr(channel)

    Process.exit(ch_pid, :kill)

    Process.sleep(1200)

    {message_id, data} = deliver_message(channel)
    assert_receive {:gun_ws, ^conn, ^stream, data_string = {type, _string}}
    assert {^message_id, "", "event.test", ^data, _} = decode_message(data_string)

    :gun.close(conn)
  end

  defp assert_receive_and_close(channel, {conn, stream}) do
    {message_id, data} = deliver_message(channel)
    assert_receive {:gun_ws, ^conn, ^stream, encoded_data}
    assert {^message_id, "", "event.test", ^data, _} = decode_message(encoded_data)
    :gun.close(conn)
    encoded_data
  end

  defp assert_stop_redelivery(protocol, %{port: port, channel: channel, secret: secret}) do
    {conn, stream} = assert_connect_and_authenticate(port, channel, secret, @binary)
    {message_id, data} = deliver_message(channel, "45")
    assert_receive {:gun_ws, ^conn, ^stream, encoded_data}
    message_id = decode_message(encoded_data) |> ProtocolMessage.message_id()
    :gun.ws_send(conn, {:text, "Ack::" <> message_id})

    refute_receive {:gun_ws, ^conn, ^stream, _}, 600

    :gun.close(conn)
  end

  defp assert_redelivery_no_ack(protocol, %{port: port, channel: channel, secret: secret}) do
    {conn, stream} = assert_connect_and_authenticate(port, channel, secret, protocol)

    {message_id, data} = deliver_message(channel)

    assert_receive {:gun_ws, ^conn, ^stream, data_string = {type, _string}}
    assert {^message_id, "", "event.test", ^data, _} = decode_message(data_string)

    assert_receive {:gun_ws, ^conn, ^stream, data_string = {^type, _string}}, 150
    assert {^message_id, "", "event.test", ^data, _} = decode_message(data_string)

    assert_receive {:gun_ws, ^conn, ^stream, data_string = {^type, _string}}, 150
    assert {^message_id, "", "event.test", ^data, _} = decode_message(data_string)

    assert_receive {:gun_ws, ^conn, ^stream, data_string = {^type, _string}}, 150
    assert {^message_id, "", "event.test", ^data, _} = decode_message(data_string)

    :gun.close(conn)
    type
  end

  defp deliver_message(channel, message_id \\ "42") do
    data = "MessageData12_3245rs42112aa"

    message =
      ProtocolMessage.to_protocol_message(%{
        message_id: message_id,
        correlation_id: "",
        message_data: data,
        event_name: "event.test"
      })

    ChannelSenderEx.Core.PubSub.PubSubCore.deliver_to_channel(channel, message)
    {message_id, data}
  end

  defp assert_receive_message(protocol, %{port: port, channel: channel, secret: secret}) do
    {conn, stream} = assert_connect_and_authenticate(port, channel, secret, protocol)

    {message_id, data} = deliver_message(channel)

    assert_receive {:gun_ws, ^conn, ^stream, encoded_data}, 400
    assert {^message_id, "", "event.test", ^data, _} = decode_message(encoded_data)
    :gun.close(conn)
    encoded_data
  end

  defp assert_reply_heartbeat(protocol, %{port: port, channel: channel, secret: secret}) do
    {conn, stream} = assert_connect_and_authenticate(port, channel, secret, protocol)

    :gun.ws_send(conn, {:text, "hb::1"})
    assert_receive {:gun_ws, ^conn, ^stream, data}
    assert {_, "1", ":hb", "", _} = decode_message(data)
    :gun.close(conn)
    data
  end

  defp assert_connect_and_authenticate(port, channel, secret, sub_protocol \\ nil) do
    {conn, stream} = assert_connect(port, channel, secret, sub_protocol)
    authenticate(conn, secret)
    assert_authenticate(conn, stream)
  end

  defp assert_authenticate(conn, stream, timeout \\ 300) do
    assert_receive {:gun_ws, ^conn, ^stream, data_string}, timeout
    message = decode_message(data_string)
    assert "AuthOk" == ProtocolMessage.event_name(message)
    {conn, stream}
  end

  defp authenticate(conn, secret), do: :gun.ws_send(conn, {:text, "Auth::#{secret}"})

  defp assert_connect(port, channel, secret, sub_protocol \\ nil) do
    conn =
      case sub_protocol do
        nil -> connect(port, channel)
        sub_protocol -> connect(port, channel, sub_protocol)
      end

    assert_receive {:gun_upgrade, ^conn, stream, ["websocket"], _headers}, 1000
    {conn, stream}
  end

  defp assert_reject(port, channel, secret, sub_protocol \\ nil) do
    conn =
      case sub_protocol do
        nil -> connect(port, channel)
        sub_protocol -> connect(port, channel, sub_protocol)
      end

    assert_receive {:gun_response, ^conn, stream, :fin, 400, _headers}, 1000
    {conn, stream}
  end

  defp connect(port, channel) do
    {:ok, conn} = connect(port)
    :gun.ws_upgrade(conn, "/ext/socket?channel=#{channel}")
    conn
  end

  defp bad_connect(port, channel) do
    {:ok, conn} = connect(port)
    :gun.ws_upgrade(conn, "/ext/socket?xxxxl=#{channel}")
    conn
  end


  defp connect(port, channel, sub_protocol) when is_list(sub_protocol) do
    {:ok, conn} = connect(port)
    protocols = Enum.map(sub_protocol, fn p -> {p, :gun_ws_h} end)
    :gun.ws_upgrade(conn, "/ext/socket?channel=#{channel}", [], %{protocols: protocols})
    conn
  end

  defp connect(port, channel, sub_protocol), do: connect(port, channel, [sub_protocol])

  defp connect(port) do
    {:ok, conn} = :gun.open(~c"127.0.0.1", port)
    {:ok, _} = :gun.await_up(conn)
    {:ok, conn}
  end

  @spec decode_message({:text, String.t()}) :: ProtocolMessage.t()
  defp decode_message({:text, data}) do
    JsonEncoder.decode_message(data)
  end

  @spec decode_message({:binary, String.t()}) :: ProtocolMessage.t()
  defp decode_message({:binary, data}) do
    IO.inspect(BinaryEncoder.decode_message(data))
  end

end
