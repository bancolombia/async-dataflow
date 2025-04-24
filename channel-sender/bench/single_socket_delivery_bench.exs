alias ChannelSenderEx.Core.Security.ChannelAuthenticator
alias ChannelSenderEx.Core.RulesProvider.Helper
alias ChannelSenderEx.Core.ProtocolMessage
alias ChannelSenderEx.Transport.EntryPoint
alias ChannelSenderEx.Core.ChannelSupervisor
alias ChannelSenderEx.Transport.Encoders.{BinaryEncoder, JsonEncoder}

defmodule SingleSocketDeliveryBench do

  @supervisor_module Application.get_env(:channel_sender_ex, :channel_supervisor_module)
  @registry_module Application.get_env(:channel_sender_ex, :registry_module)

  def setup do
    IO.puts("Starting Applications for Socket Bench")
    Helper.compile(:channel_sender_ex, socket_idle_timeout: 60000)
    {:ok, _} = Application.ensure_all_started(:cowboy)
    {:ok, _} = Application.ensure_all_started(:gun)
    {:ok, _} = Application.ensure_all_started(:plug_crypto)
    {:ok, _pid_supervisor} = @supervisor_module.start_link(name: ChannelSupervisor, strategy: :one_for_one)
    [ok: _] = EntryPoint.start(0)
    {:ok, :ranch.get_port(:external_server)}
  end

  def connect_and_authenticate(port, channel, secret, sub_protocol \\ "json_flow") do
    conn = connect(port, channel, sub_protocol)

    stream = receive do
      resp = {:gun_upgrade, ^conn, stream, _, _headers} -> stream
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

  defp connect(port, channel, sub_protocol) do
    {:ok, conn} = :gun.open('127.0.0.1', port)
    {:ok, _} = :gun.await_up(conn)
    :gun.ws_upgrade(conn, "/ext/socket?channel=#{channel}", [], %{protocols: [{sub_protocol, :gun_ws_h}]})
    conn
  end
end

{:ok, port} = SingleSocketDeliveryBench.setup()

sample_object = %{
  number: 334433,
  id: UUID.uuid4(:hex),
  name: "Person Name LastName Complement",
  name2: "Person Name LastName Complement",
  list_of_things: [
    %{name: "Thing1", detail: 2343, id: UUID.uuid4(:hex)},
    %{name: "Thing2", detail: 2343, id: UUID.uuid4(:hex)},
    %{name: "Thing3", detail: 2343, id: UUID.uuid4(:hex)},
    %{name: "Thing4", detail: 2343, id: UUID.uuid4(:hex)},
  ]
}

data = Jason.encode!(sample_object)

base_message = %{
  message_id: UUID.uuid4(:hex),
  correlation_id: "",
  message_data: data,
  event_name: "event.test.name.application"
}

send_and_receive_sequential = fn {conn, stream, channel_id} ->
#  Process.sleep(:erlang.trunc(:random.uniform * 5))
  message = ProtocolMessage.to_protocol_message(%{base_message | message_id: msg_id = UUID.uuid4(:hex)})
  ChannelSenderEx.Core.PubSub.PubSubCore.deliver_to_channel(channel_id, message)
  receive do
    {:gun_ws, ^conn, ^stream, {:text, data}} ->
      {message_id, _, _, _, _} = JsonEncoder.decode_message(data)
      :gun.ws_send(conn, {:text, "Ack::" <> message_id})
    {:gun_ws, ^conn, ^stream, {:binary, data}} ->
      {message_id, _, _, _, _} = BinaryEncoder.decode_message(data)
      :gun.ws_send(conn, {:text, "Ack::" <> message_id})
  after
    100 ->
      raise "No message!"
  end
end

prepare_scenario = fn sub_protocol ->
  {:ok, _, _, channel_id, channel_secret} = SingleSocketDeliveryBench.create_channel()
  {:ok, conn, stream} = SingleSocketDeliveryBench.connect_and_authenticate(port, channel_id, channel_secret, sub_protocol)
  {conn, stream, channel_id}
end

Benchee.run(
  %{
    "Sequential send and receive / JsonEncoder" =>
      {
      send_and_receive_sequential,
      before_scenario: fn _input -> prepare_scenario.("json_flow") end
    },
    "Sequential send and receive / BinaryEncoder" =>
      {
      send_and_receive_sequential,
      before_scenario: fn _input -> prepare_scenario.("binary_flow") end
    },
  },
  inputs: %{
    "Input" => 1,
  },
  time: 10,
  parallel: 12,
  formatters: [{Benchee.Formatters.Console, extended_statistics: true}]
)
