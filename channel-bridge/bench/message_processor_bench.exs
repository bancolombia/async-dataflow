alias ChannelBridgeEx.Entrypoint.Pubsub.MessageProcessor
alias ChannelBridgeEx.Core.Channel
alias ChannelBridgeEx.Boundary.ChannelSupervisor
alias ChannelBridgeEx.Boundary.ChannelManager
alias ChannelBridgeEx.Core.AppClient
alias ChannelBridgeEx.Core.User

## This bench only measures internal components for handling/delivering messages
## to ADF Sender.
## There is other bench that measures the ADF sender's rest endpoint throughtput
## see sender_deliver_bench.exs.

non_deliverable_message = "{
  \"data\": {
    \"headers\": {
      \"header1\": \"foo\",
      \"header2\": \"bar\"
    },
    \"request\": {
      \"msg\": \"Hello World, Much Wow!\"
    },
    \"response\": {
      \"msg\": \"Lorem Ipsum\"
    }
  },
  \"dataContentType\": \"application/json\",
  \"id\": \"99999999\",
  \"source\": \"source1\",
  \"specVersion\": \"0.1\",
  \"time\": \"xxx\",
  \"subject\": \"xxxxx\",
  \"type\": \"type1\"
}"

deliverable_message = "{
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


app_ref = AppClient.new("abc321", "ABC Application")
user_ref = User.new("user1")

# Registers 10 process channels with a mocked or real instance of
# ADF Sender, with names foo1 ... to foo10
Enum.map(1..10, fn ch ->
  Channel.new("foo" <> to_string(ch), app_ref, user_ref)
  |> ChannelSupervisor.start_channel_process
  |> (fn {:ok, channel_pid} ->
    ChannelManager.open_channel(channel_pid)
  end).()
end)

Process.sleep(200)

# Function for randomnly assing a channel name (from foo1 ... to foo10)
# to a message prior delivery.
build_msg = fn() ->
  chid = :rand.uniform(10)
  String.replace(deliverable_message, "foo#", "foo" <> to_string(chid))
end

Benchee.run(
  %{
    "Process deliverable message" => fn msg -> MessageProcessor.handle_message(msg) end,
    "Process no deliverable message" => fn msg -> MessageProcessor.handle_message(non_deliverable_message) end
  },
  before_each: fn (_) -> build_msg.() end,
  warmup: 2,
  time: 8,
  parallel: 2,
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
# parallel: 2
# inputs: none specified
# Estimated total run time: 20 s

# Benchmarking Process deliverable message...
# Benchmarking Process no deliverable message...

# Name                                     ips        average  deviation         median         99th %
# Process no deliverable message       51.46 K       19.43 μs    ±66.21%       16.76 μs       66.08 μs
# Process deliverable message          48.61 K       20.57 μs    ±74.57%       16.41 μs       52.05 μs

# Comparison:
# Process no deliverable message       51.46 K
# Process deliverable message          48.61 K - 1.06x slower +1.14 μs

# Extended statistics:

# Name                                   minimum        maximum    sample size                     mode
# Process no deliverable message        11.10 μs     5071.85 μs       699.72 K                 16.39 μs
# Process deliverable message           10.73 μs      960.40 μs       649.33 K                 14.24 μs
