alias AdfSenderConnector.Message

children = [
  AdfSenderConnector.http_client_spec()
]

Supervisor.start_link(children, strategy: :one_for_one)

{:ok, response} = AdfSenderConnector.channel_registration("a", "b")
channel_ref = Map.fetch!(response, "channel_ref")

create_msg = fn ->
  msgid = "#{UUID.uuid4()}"
  Message.new(channel_ref, msgid, nil, "{ \"hello\": \"world\" }", "event.name")
end

Benchee.run(
  %{
    "deliver messages" => {fn msg ->
      AdfSenderConnector.route_message(msg)
    end, before_scenario: fn _input -> create_msg.() end}
  },
  warmup: 2,
  time: 8,
  parallel: 1,
  formatters: [{Benchee.Formatters.Console, extended_statistics: true}],
  profile_after: true
)
