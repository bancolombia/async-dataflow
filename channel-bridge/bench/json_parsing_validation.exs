alias ChannelBridgeEx.Core.CloudEvent

json_message = "{
  \"data\": {
      \"msg\": \"Hello World, Much Wow!\"
  },
  \"dataContentType\": \"application/json\",
  \"id\": \"A234-1234-1234\",
  \"source\": \"https://organization.com/cloudevents/operation\",
  \"specVersion\": \"1.0\",
  \"time\": \"2018-04-05T17:31:00Z\",
  \"subject\": \"foo#\",
  \"type\": \"bussines.event.transaction.completed\"
}"

invalid_message = "{
  \"data\": {
    \"headers\": {
      \"channel\": \"BLM\",
      \"application-id\": \"abc321\"
    }
}"

# Function for randomnly assing a channel name (from foo1 ... to foo10)
# to a message prior delivery.
build_msg = fn() ->
  chid = :rand.uniform(10)
  if chid <= 5 do
    json_message
  else
    invalid_message
  end
end


Benchee.run(
  %{
    "Parse and validate correct json" => fn  ->
      CloudEvent.from(json_message)
    end,
    "Parse and validate incorrect Json" => fn  ->
      CloudEvent.from(invalid_message)
    end,
  },
  # before_each: fn (_) -> build_msg.() end,
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
# Estimated total run time: 20 s

# Benchmarking Parse and validate correct json...
# Benchmarking Parse and validate incorrect Json...

# Name                                        ips        average  deviation         median         99th %
# Parse and validate incorrect Json      743.70 K        1.34 μs  ±1851.52%        1.13 μs        1.74 μs
# Parse and validate correct json        131.15 K        7.62 μs   ±226.65%        6.95 μs       13.40 μs

# Comparison:
# Parse and validate incorrect Json      743.70 K
# Parse and validate correct json        131.15 K - 5.67x slower +6.28 μs

# Extended statistics:

# Name                                      minimum        maximum    sample size                     mode
# Parse and validate incorrect Json         1.04 μs    32526.28 μs         4.29 M                  1.13 μs
# Parse and validate correct json           6.52 μs     9223.21 μs       978.38 K                  6.84 μs
