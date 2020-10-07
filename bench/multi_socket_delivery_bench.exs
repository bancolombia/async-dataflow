alias ChannelSenderEx.Core.Security.ChannelAuthenticator
alias ChannelSenderEx.Core.RulesProvider.Helper
alias ChannelSenderEx.Core.ProtocolMessage
alias ChannelSenderEx.Transport.EntryPoint
alias ChannelSenderEx.Core.ChannelSupervisor
alias ChannelSenderEx.Core.ChannelRegistry

defmodule SingleSocketDeliveryBench do

  @supervisor_module Application.get_env(:channel_sender_ex, :channel_supervisor_module)
  @registry_module Application.get_env(:channel_sender_ex, :registry_module)

  def setup do
    IO.puts("Starting Applications for Socket Bench")
    Helper.compile(:channel_sender_ex, socket_idle_timeout: 60000)
    {:ok, _} = Application.ensure_all_started(:cowboy)
    {:ok, _} = Application.ensure_all_started(:gun)
    {:ok, _} = Application.ensure_all_started(:plug_crypto)
    {:ok, _pid_registry} = @registry_module.start_link(name: ChannelRegistry, keys: :unique)
    {:ok, _pid_supervisor} = @supervisor_module.start_link(name: ChannelSupervisor, strategy: :one_for_one)
    [ok: _] = EntryPoint.start(0)
    {:ok, :ranch.get_port(:external_server)}
  end

  def connect_and_authenticate(port, channel, secret) do
    conn = connect(port, channel)

    stream = receive do
      {:gun_upgrade, ^conn, stream, ["websocket"], _headers} -> stream
    after
      1000 -> raise "Websocket upgrade timeout!"
    end

    :gun.ws_send(conn, {:text, "Auth::#{secret}"})

    data_string = receive do
      {:gun_ws, ^conn, ^stream, {:text, data_string}} -> data_string
    after
      1000 -> raise "Auth response timeout!"
    end

    message = Jason.decode!(data_string) |> ProtocolMessage.from_socket_message()
    "AuthOk" = ProtocolMessage.event_name(message)
    {:ok, conn, stream}
  end

  def create_channel() do
    app_id = "app_22929"
    user_id = "user33243222"
    {channel_id, channel_secret} = ChannelAuthenticator.create_channel(app_id, user_id)
    {:ok, app_id, user_id, channel_id, channel_secret}
  end

  defp connect(port, channel) do
    {:ok, conn} = :gun.open('127.0.0.1', port)
    {:ok, _} = :gun.await_up(conn)
    :gun.ws_upgrade(conn, "/ext/socket?channel=#{channel}")
    conn
  end
end

{:ok, port} = SingleSocketDeliveryBench.setup()


base_message = %{
  message_id: "42",
  correlation_id: "",
  message_data: "MessageData12_3245rs42112aa",
  event_name: "event.test"
}


send_and_receive_sequential = fn {conn, stream, channel_id} ->
  Process.sleep(:erlang.trunc(:random.uniform * 5))
  message = ProtocolMessage.to_protocol_message(%{base_message | message_id: msg_id = UUID.uuid4(:hex)})
  ChannelSenderEx.Core.PubSub.PubSubCore.deliver_to_channel(channel_id, message)
  receive do
    {:gun_ws, ^conn, ^stream, {:text, data_string}} ->
      :gun.ws_send(conn, {:text, "Ack::" <> msg_id})
      :ok
  after
    100 ->
      raise "No message!"
  end
end


Benchee.run(
  %{
    "Sequential send and receive" =>
      {
      send_and_receive_sequential,
      before_scenario: fn _input ->
          {:ok, _, _, channel_id, channel_secret} = SingleSocketDeliveryBench.create_channel()
          {:ok, conn, stream} = SingleSocketDeliveryBench.connect_and_authenticate(port, channel_id, channel_secret)
          {conn, stream, channel_id}
      end
    }
  },
  inputs: %{
    "Input" => 1,
  },
  time: 10,
  parallel: 10,
  formatters: [{Benchee.Formatters.Console, extended_statistics: true}]
)
