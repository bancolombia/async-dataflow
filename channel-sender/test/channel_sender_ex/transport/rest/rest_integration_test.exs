defmodule ChannelSenderEx.Transport.Rest.RestIntegrationTest do
  use ExUnit.Case
  use Plug.Test
  import Mock

  alias ChannelSenderEx.Core.RulesProvider.Helper
  alias ChannelSenderEx.Transport.Rest.RestController
  alias ChannelSenderEx.Persistence.RedisSupervisor
  alias ChannelSenderEx.Adapter.WsConnections

  @moduletag :capture_log
  @options RestController.init([])

  setup_all do
    IO.puts("Starting Applications for Rest Integration Test")

    Application.put_env(:channel_sender_ex, :secret_base, {
        "aV4ZPOf7T7HX6GvbhwyBlDM8B9jfeiwi+9qkBnjXxUZXqAeTrehojWKHkV3U0kGc",
        "socket auth"
    })

    Application.put_env(:channel_sender_ex, :persistence,
      [enabled: true, type: :redis,
        config: [
          host: "127.0.0.1",
          host_read: "127.0.0.1",
          port: 6379,
          ssl: false
        ]])

    Application.put_env(:channel_sender_ex, :persistence_module,
      ChannelSenderEx.Persistence.RedisChannelPersistence)

    {:ok, _} = Application.ensure_all_started(:gun)
    {:ok, _} = Application.ensure_all_started(:plug_crypto)
    Helper.compile(:channel_sender_ex)

    # ! TODO FIX: this integration test needs a redis server running
    # ! TODO FIX: maybe provide a library to simulate a redis on localhost

    # {:ok, redis_pid} = Redex.Server.start_link([port: 6379])
    cfg = Application.get_env(:channel_sender_ex, :persistence)
    RedisSupervisor.start_link(Keyword.get(cfg, :config, []))

    :poolboy.start_link([
        name: {:local, :channel_worker},
        worker_module: ChannelSenderEx.Core.ChannelWorker,
        size: 5,
        max_overflow: 10
    ])

    # {:ok, pid_supervisor} =
    #   Horde.DynamicSupervisor.start_link(name: MessageProcessSupervisor, strategy: :one_for_one)

    on_exit(fn ->
      Application.delete_env(:channel_sender_ex, :accept_channel_reply_timeout)
      Application.delete_env(:channel_sender_ex, :on_connected_channel_reply_timeout)
      Application.delete_env(:channel_sender_ex, :secret_base)
      Application.delete_env(:channel_sender_ex, :persistence_module)

      # true = Process.exit(pid_supervisor, :normal)
      # Process.exit(redis_pid, :normal)
    end)

    :ok
  end

  test "Should create channel" do

    body = Jason.encode!(%{application_ref: "some_application", user_ref: "user_ref_00117ALM"})

    conn = conn(:post, "/ext/channel/create", body)
    |> put_req_header("content-type", "application/json")

    conn = RestController.call(conn, @options)

    assert conn.status == 200
  end

  test "Should handle invalid body when createing channel" do

    body = Jason.encode!(%{foo: "bar"})

    conn = conn(:post, "/ext/channel/create", body)
    |> put_req_header("content-type", "application/json")
    conn = RestController.call(conn, @options)

    assert conn.status == 400

    assert %{"error" => "Invalid request", "request" => %{"foo" => "bar"}} =
             Jason.decode!(conn.resp_body)

  end

  test "Should handle a gateway client connection" do

    # first create a channel
    %{"channel_ref" => channel_ref,
      "channel_secret" => _secret} = create_channel("App1", "User1234")

    Process.sleep(10)

    # then run the logic when a client connects to the channel
    assert %{"message" => "OK"} = connect_channel(generate_random_string(10), channel_ref)
  end

  test "Should handle a gateway authentication" do

    # first create a channel
    %{"channel_ref" => channel_ref,
      "channel_secret" => secret} = create_channel("App1", "User1234")

    Process.sleep(10) # wait for the channel to be created and data persisted

    # then run the logic when a client connects to the channel
    connection_id = generate_random_string(10)
    assert %{"message" => "OK"} = connect_channel(connection_id, channel_ref)

    Process.sleep(10) # wait for the channel-socket relation to be persisted

    # then run the logic when a client authenticates to the channel
    assert {200, ["", "", "AuthOk", ""]} = auth_channel(connection_id, secret)
  end

  test "Should handle a gateway failed authentication" do

    # first create a channel
    %{"channel_ref" => channel_ref,
      "channel_secret" => _} = create_channel("App1", "User1234")

    Process.sleep(10) # wait for the channel to be created and data persisted

    # then run the logic when a client connects to the channel
    connection_id = generate_random_string(10)
    assert %{"message" => "OK"} = connect_channel(connection_id, channel_ref)

    Process.sleep(10) # wait for the channel-socket relation to be persisted

    # then run the logic when a client authenticates to the channel
    assert {401, ["", "", "AuthFailed", ""]} = auth_channel(connection_id, "invalidsecret")
  end

  test "Should handle a gateway heart-beat message" do
    # first create a channel
    %{"channel_ref" => channel_ref,
      "channel_secret" => secret} = create_channel("App1", "User1234")

    Process.sleep(10) # wait for the channel to be created and data persisted

    # then run the logic when a client connects to the channel
    connection_id = generate_random_string(10)
    assert %{"message" => "OK"} = connect_channel(connection_id, channel_ref)

    Process.sleep(10) # wait for the channel-socket relation to be persisted

    # then authenticate the channel
    assert {200, ["", "", "AuthOk", ""]} = auth_channel(connection_id, secret)

    # then process the reception of a heart-beat message
    assert {200, ["", _hbid, ":hb", ""]} = heart_beat(connection_id)
  end

  test "Should handle a gateway ack message" do
    # first create a channel
    %{"channel_ref" => channel_ref,
      "channel_secret" => secret} = create_channel("App1", "User1234")

    Process.sleep(10) # wait for the channel to be created and data persisted

    # then run the logic when a client connects to the channel
    connection_id = generate_random_string(10)
    assert %{"message" => "OK"} = connect_channel(connection_id, channel_ref)

    Process.sleep(10) # wait for the channel-socket relation to be persisted

    # then authenticate the channel
    assert {200, ["", "", "AuthOk", ""]} = auth_channel(connection_id, secret)
    Process.sleep(50)

    with_mocks([
      {WsConnections, [], [
        send_data: fn(_connection_id, _data) -> :ok end,
        close: fn(_conn_id) -> :ok end
      ]}
    ]) do
      # then request the routing of a message
      assert {202, %{"result" => "Ok"}, message_id} = deliver_message(channel_ref)
      Process.sleep(150)

      # then program the emision of the ack message
      Task.start(fn ->
        Process.sleep(150)
        assert {200, ""} = ack_message(connection_id, message_id)
      end)

      Process.sleep(2500) # wait for the ack message to be sent

      # assert mock was called
      # assert_called_exactly WsConnections.close(:_), 1
    end
  end

  # ------------------------------------------
  # Helper functions
  # ------------------------------------------

  defp create_channel(app, user) do
    body = Jason.encode!(%{application_ref: app, user_ref: user})

    conn = conn(:post, "/ext/channel/create", body)
    |> put_req_header("content-type", "application/json")
    conn = RestController.call(conn, @options)

    assert conn.status == 200

    Jason.decode!(conn.resp_body)
  end

  defp connect_channel(connection_id, channel_ref) do
    body = Jason.encode!(%{})

    conn = conn(:post, "/ext/channel/gateway/connect", body)
    |> put_req_header("content-type", "application/json")
    |> put_req_header("connectionid", connection_id)
    |> put_req_header("channel", channel_ref)

    conn = RestController.call(conn, @options)

    assert conn.status == 200

    Jason.decode!(conn.resp_body)
  end

  defp auth_channel(connection_id, secret) do
    body = Jason.encode!(%{payload: "Auth::#{secret}"})

    conn = conn(:post, "/ext/channel/gateway/message", body)
    |> put_req_header("content-type", "application/json")
    |> put_req_header("connectionid", connection_id)

    conn = RestController.call(conn, @options)

    {conn.status, Jason.decode!(conn.resp_body)}
  end

  defp ack_message(connection_id, message_id) do
    body = Jason.encode!(%{payload: "Ack::#{message_id}"})

    conn = conn(:post, "/ext/channel/gateway/message", body)
    |> put_req_header("content-type", "application/json")
    |> put_req_header("connectionid", connection_id)

    conn = RestController.call(conn, @options)
    resp = conn.resp_body
    case resp do
      "" -> {conn.status, resp}
      _ -> {conn.status, Jason.decode!(resp)}
    end
  end

  defp heart_beat(connection_id) do
    body = Jason.encode!(%{payload: "hb::1"})

    conn = conn(:post, "/ext/channel/gateway/message", body)
    |> put_req_header("content-type", "application/json")
    |> put_req_header("connectionid", connection_id)

    conn = RestController.call(conn, @options)

    {conn.status, Jason.decode!(conn.resp_body)}
  end

  defp deliver_message(channel_ref) do

    message_id = UUID.uuid4()
    body = Jason.encode!(%{
      "channel_ref" => channel_ref,
      "message_id" => message_id,
      "correlation_id" => UUID.uuid4(),
      "message_data" => "Hello",
      "event_name" => "event.example"
    })

    conn = conn(:post, "/ext/channel/deliver_message", body)
    |> put_req_header("content-type", "application/json")

    conn = RestController.call(conn, @options)

    {conn.status, Jason.decode!(conn.resp_body), message_id}
  end

  defp generate_random_string(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.encode64
    |> String.slice(0..length - 1)
  end

end
