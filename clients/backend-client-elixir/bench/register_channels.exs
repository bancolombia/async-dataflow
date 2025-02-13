alias AdfSenderConnector.Channel

children = [
  AdfSenderConnector.http_client_spec()
]

Supervisor.start_link(children, strategy: :one_for_one)

Benchee.run(
  %{
    "register channels" => fn user_ref ->
      {:ok, pid} = AdfSenderConnector.channel_registration("app_ref1", user_ref)
    end
  },
  before_each: fn (_) -> "user_" <> to_string(:rand.uniform(1000000000000)) end,
  warmup: 2,
  time: 8,
  parallel: 1,
  formatters: [{Benchee.Formatters.Console, extended_statistics: true}],
  profile_after: true
)