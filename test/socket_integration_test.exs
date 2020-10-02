defmodule SocketIntegrationTest do
  use ExUnit.Case

  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Transport.EntryPoint
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
  alias ChannelSenderEx.Core.ProtocolMessage

  @moduletag :capture_log

  setup_all do
    IO.puts("Starting Applications for Socket Test")
    {:ok, _} = Application.ensure_all_started(:cowboy)
    {:ok, _} = Application.ensure_all_started(:gun)
    {:ok, _} = Application.ensure_all_started(:plug_crypto)

    ext_message = %{
      message_id: "id_msg0001",
      correlation_id: "1111",
      message_data: "Some_messageData",
      event_name: "event.example"
    }

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

  test "Should connect to socket", %{port: port, channel: channel} do
    conn = connect(port, channel)
    assert_receive {:gun_upgrade, ^conn, stream, ["websocket"], _headers}
    :gun.close(conn)
  end

  test "Should authenticate", %{port: port, channel: channel, secret: secret} do
    conn = connect(port, channel)
    assert_receive {:gun_upgrade, ^conn, stream, ["websocket"], _headers}
    :gun.ws_send(conn, {:text, "Auth::#{secret}"})
    assert_receive {:gun_ws, ^conn, ^stream, {:text, data_string}}
    message = decode_message(data_string)
    assert "AuthOk" == ProtocolMessage.event_name(message)
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

  test "Should reply heartbeat", %{port: port, channel: channel, secret: secret} do
    conn = connect(port, channel)
    assert_receive {:gun_upgrade, ^conn, stream, ["websocket"], _headers}
    :gun.ws_send(conn, {:text, "Auth::#{secret}"})

    assert_receive {:gun_ws, ^conn, ^stream, {:text, data_string}}
    message = decode_message(data_string)
    assert "AuthOk" == ProtocolMessage.event_name(message)

    :gun.ws_send(conn, {:text, "hb::1"})
    assert_receive {:gun_ws, ^conn, ^stream, {:text, data_string}}
    IO.inspect(data_string)
    assert {_, "1", ":hb", "", _} = decode_message(data_string)
    :gun.close(conn)
  end

  defp connect(port, channel) do
    {:ok, conn} = :gun.open('127.0.0.1', port)
    {:ok, _} = :gun.await_up(conn)
    :gun.ws_upgrade(conn, "/ext/socket?channel=#{channel}")
    conn
  end

  @spec decode_message(String.t()) :: ProtocolMessage.t()
  defp decode_message(string_data) do
    socket_message = Jason.decode!(string_data)
    ProtocolMessage.from_socket_message(socket_message)
  end

  test "Should 1", %{message: _message, port: port} do
    {:ok, conn} = :gun.open('127.0.0.1', port)

    IO.puts("In test")

    #    assert {[], {"channel1", :connected, {"app1", "user2"}, pending}} = result
    #    assert pending == %{}
    #    assert_receive {:ack, ^ref, ^message_id}
    :gun.close(conn)
  end

  test "Should 2", %{message: _message, ext_message: _ext_message, port: port} do
    {:ok, conn} = :gun.open('127.0.0.1', port)

    IO.puts("In test")

    #    assert {[], {"channel1", :connected, {"app1", "user2"}, pending}} = result
    #    assert pending == %{}
    #    assert_receive {:ack, ^ref, ^message_id}
    :gun.close(conn)
  end
end
