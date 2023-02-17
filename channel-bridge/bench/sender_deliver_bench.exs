
## This bench measures the throughtput of ADF sender's rest endpoint for routing messages.
## ADF Sender Repo https://github.com/bancolombia/async-dataflow/tree/master/channel-sender

register_ch = fn() ->
  ran_id = :rand.uniform(99999) |> to_string
  message = %{
    "application_ref" => "app_" <> ran_id,
    "user_ref" => "user_" <> ran_id
  }
  HTTPoison.post "http://localhost:8081/ext/channel/create", Jason.encode!(message), [
    {"Content-Type", "application/json"},
  ], hackney: [pool: :default]
end

# # opens N channels
channels = Enum.map(1..10, fn ch ->
  {:ok, response} = register_ch.()
  Jason.decode!(response.body) |> Map.get("channel_ref")
end)

deliver_msg = fn(ch_ref) ->
  ran_id = :rand.uniform(99999) |> to_string
  message = %{
    "channel_ref" => ch_ref,
    "message_id" => "0" <> ran_id,
    "correlation_id" => "0" <> ran_id,
    "message_data" => %{
        "body" => "Hello World"
    },
    "event_name" => "bussiness.xxx.xx.xx.xxx"
  }
  HTTPoison.post "http://localhost:8081/ext/channel/deliver_message", Jason.encode!(message), [
    {"Content-Type", "application/json"},
  ], hackney: [pool: :default]
end

Benchee.run(
  %{
    "send message" => fn channel -> deliver_msg.(channel) end
  },
  before_each: fn (_) -> Enum.random(channels) end,
  warmup: 2,
  time: 8,
  parallel: 1,
  formatters: [{Benchee.Formatters.Console, extended_statistics: true}]
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

# Benchmarking send message...

# Name                   ips        average  deviation         median         99th %
# send message        405.40        2.47 ms    ±12.31%        2.42 ms        3.44 ms

# Extended statistics:

# Name                 minimum        maximum    sample size                     mode
# send message         1.96 ms       10.06 ms         3.24 K2.57 ms, 2.21 ms, 2.43 ms
