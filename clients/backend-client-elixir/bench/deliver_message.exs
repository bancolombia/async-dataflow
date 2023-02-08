alias AdfSenderConnector.Message

children = [
  AdfSenderConnector.spec(),
  AdfSenderConnector.registry_spec()
]

Supervisor.start_link(children, strategy: :one_for_one)

options = [sender_url: "http://localhost:8082", http_opts: []]

{:ok, response} = AdfSenderConnector.channel_registration("a", "b", options)

channel_ref = Map.fetch!(response, "channel_ref")

message =  Message.new(channel_ref, "custom.message.id", "custom.correlation.id", "{ \"hello\": \"world\" }", "event.name")

Benchee.run(
  %{
    "deliver messages" => fn ->
      AdfSenderConnector.route_message(channel_ref, "event.name", message)
    end
  },
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
# Elixir 1.14.0
# Erlang 25.0.4

# Benchmark suite executing with the following configuration:
# warmup: 2 s
# time: 8 s
# memory time: 0 ns
# reduction time: 0 ns
# parallel: 1
# inputs: none specified
# Estimated total run time: 10 s

# Benchmarking deliver messages ...

# Name                       ips        average  deviation         median         99th %
# deliver messages      662.16 K        1.51 μs  ±3008.33%        1.18 μs        3.73 μs

# Extended statistics:

# Name                     minimum        maximum    sample size                     mode
# deliver messages         0.84 μs    56185.68 μs         3.80 M                  1.15 μs
