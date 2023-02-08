alias AdfSenderConnector.Channel

children = [
  AdfSenderConnector.spec(),
  AdfSenderConnector.registry_spec()
]

Supervisor.start_link(children, strategy: :one_for_one)

options = [sender_url: "http://localhost:8082", http_opts: []]

Benchee.run(
  %{
    "register channels" => fn user_ref ->
      {:ok, pid} = AdfSenderConnector.channel_registration("app_ref1", user_ref, options)
    end
  },
  before_each: fn (_) -> "user_" <> to_string(:rand.uniform(1000000000000)) end,
  warmup: 2,
  time: 8,
  parallel: 1,
  formatters: [{Benchee.Formatters.Console, extended_statistics: true}],
  profile_after: true
)


# Operating System: macOS
# CPU Information: Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz
# Number of Available Cores: 12
# Available memory: 16 GB
# Elixir 1.13.4
# Erlang 25.0.2

# Benchmark suite executing with the following configuration:
# warmup: 2 s
# time: 8 s
# memory time: 0 ns
# parallel: 1
# inputs: none specified
# Estimated total run time: 10 s

# Benchmarking deliver messages...

# Name                       ips        average  deviation         median         99th %
# deliver messages        344.02        2.91 ms    ±13.59%        2.83 ms        4.38 ms

# Extended statistics:

# Name                     minimum        maximum    sample size                     mode
# deliver messages         2.26 ms       11.06 ms         2.75 K2.92 ms, 2.62 ms, 2.88 ms
