defmodule ChannelSenderEx.Transport.SseIntegrationTest do
  use ExUnit.Case

  alias ChannelSenderEx.Core.ChannelRegistry
  alias ChannelSenderEx.Core.ChannelSupervisor
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.ProtocolMessage
  alias ChannelSenderEx.Core.PubSub.PubSubCore
  alias ChannelSenderEx.Core.RulesProvider.Helper
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
  alias ChannelSenderEx.Transport.Encoders.JsonEncoder
  alias ChannelSenderEx.Transport.EntryPoint

  @moduletag :capture_log

  setup_all do
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

  test "Should handle non validatable secret", %{port: port, channel: channel} do
    {conn, _ref} = connect(port, channel, "bad secret")
    assert_receive {:gun_data, _pid, _ref, :fin, "{\"error\":\"3008\"}"}, 300
    :gun.close(conn)
  end

  test "Should handle empty authorization header sent", %{port: port, channel: channel} do
    {:ok, conn} = connect(port)
    _stream_ref = :gun.get(conn, "/ext/sse?channel=#{channel}", [
      {"accept", "text/event-stream"}, {"authorization", ""}])
    assert_receive {:gun_data, _, _, :fin, "{\"error\":\"3008\"}"}, 300
    :gun.close(conn)
  end

  test "Should handle no authorization header sent", %{port: port, channel: channel} do
    {:ok, conn} = connect(port)
    _stream_ref = :gun.get(conn, "/ext/sse?channel=#{channel}", [
      {"accept", "text/event-stream"}])
    assert_receive {:gun_data, _, _, :fin, "{\"error\":\"3008\"}"}, 300
    :gun.close(conn)
  end

  test "Should handle invalid authorization header sent", %{port: port, channel: channel} do
    {:ok, conn} = connect(port)
    _stream_ref = :gun.get(conn, "/ext/sse?channel=#{channel}", [
      {"accept", "text/event-stream"}, {"authorization", "Bearer"}])
    assert_receive {:gun_data, _, _, :fin, "{\"error\":\"3008\"}"}, 300
    :gun.close(conn)
  end

  test "Should handle invalid channel", %{port: port, secret: secret} do
    {conn, _ref} = connect(port, "x", secret)
    assert_receive {:gun_response, _pid, _ref, :nofin, 400, response_headers}, 1500
    assert Enum.any?(response_headers, fn
      {"x-error-code", "3006"} -> true
      _ -> false
    end)
    assert_receive {:gun_data, _, _, :fin, "{\"error\":\"3006\"}"}
    :gun.close(conn)
  end

  test "Should handle unexistent channel", %{port: port, secret: secret} do
    {conn, _ref} = connect(port, "715234af6eb132948446c8536502a13f.3bfa5270941b4d358897fa669010399a", secret)
    assert_receive {:gun_response, _pid, _ref, :nofin, 428, response_headers}, 1500
    assert Enum.any?(response_headers, fn
      {"x-error-code", "3050"} -> true
      _ -> false
    end)
    assert_receive {:gun_data, _, _, :fin, "{\"error\":\"3050\"}"}
    :gun.close(conn)
  end

  test "Should handle invalid request", %{port: port} do
    {:ok, conn} = connect(port)
    _stream_ref = :gun.get(conn, "/ext/sse", [{"accept", "text/event-stream"}])
    assert_receive {:gun_response, _pid, _ref, :nofin, 400, response_headers}, 300
    assert Enum.any?(response_headers, fn
      {"x-error-code", "3006"} -> true
      _ -> false
    end)
    :gun.close(conn)
  end

  test "Should handle options method", %{port: port, channel: channel} do
    {:ok, conn} = connect(port)
    _stream_ref = :gun.options(conn, "/ext/sse?channel=#{channel}", [{"accept", "text/event-stream"}])
    assert_receive {:gun_response, _pid, _ref, :fin, 204, response_headers}, 300
    assert response_headers |> Enum.any?(fn {k, v} -> String.starts_with?(k, "access-control-allow") end)
    :gun.close(conn)
  end

  test "Should handle fail on other methods", %{port: port, channel: channel} do
    {:ok, conn} = connect(port)
    _stream_ref = :gun.put(conn, "/ext/sse?channel=#{channel}", [{"accept", "text/event-stream"}])
    assert_receive {:gun_response, _pid, _ref, :fin, 405, _response_headers}, 300
    :gun.close(conn)
  end

  test "Should connect to sse endpoint", %{port: port, channel: channel, secret: secret} do
    conn = connect(port, channel, secret)
    assert_receive {
      :gun_response,
      _pid,
      _ref,
      :nofin,
      200,
      response_headers
    }, 300

    # assert response_headers list contains "Content-Type: text/event-stream"
    assert Enum.any?(response_headers, fn
      {"content-type", "text/event-stream"} -> true
      _ -> false
    end)

    :gun.close(conn)
  end

  test "Should receive messages", params do
    assert_receive_message(params)
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

    PubSubCore.deliver_to_channel(channel, message)
    {message_id, data}
  end

  defp assert_receive_message(%{port: port, channel: channel, secret: secret}) do
    {conn, _stream} = connect(port, channel, secret)

    {message_id, data} = deliver_message(channel)

    assert_receive {:gun_data, _pid, _ref, :nofin, encoded_data}, 400

    assert {^message_id, "", "event.test", ^data, _} = decode_message(encoded_data)

    :gun.close(conn)
    encoded_data
  end

  defp connect(port, channel, secret) do
    {:ok, conn} = connect(port)
    stream_ref = :gun.get(conn, "/ext/sse?channel=#{channel}", [
      {"accept", "text/event-stream"},
      {"authorization", "Bearer #{secret}"}
      ])
    {conn, stream_ref}
  end

  defp connect(port) do
    {:ok, conn} = :gun.open(~c"127.0.0.1", port, %{transport: :tcp})
    {:ok, _} = :gun.await_up(conn)
    {:ok, conn}
  end

  @spec decode_message(String.t()) :: ProtocolMessage.t()
  defp decode_message(data) do
    JsonEncoder.decode_message(String.slice(data, 6, String.length(data) - 6))
  end

end
