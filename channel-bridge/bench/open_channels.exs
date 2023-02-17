alias ChannelBridgeEx.Entrypoint.Rest.RestHelper

defmodule HttpClient do
  def connection(host, port, opts \\ [keepalive: :infinity]) do
    host = to_charlist(host)
    connect_opts = %{
      connect_timeout: :timer.minutes(1),
      retry: 10,
      retry_timeout: 100,
      http_opts: %{keepalive: opts[:keepalive]},
      http2_opts: %{keepalive: opts[:keepalive]}
    }

    with {:ok, conn_pid} <- :gun.open(host, port, connect_opts),
         {:ok, _protocol} <- :gun.await_up(conn_pid, :timer.minutes(1)) do
      {:ok, conn_pid}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  def post(conn_pid, query, body, headers \\ %{}) do
    headers = convert_to_elixir(headers)
    headers = [{"content-length", byte_size(body)} | headers]
    monitor_ref = Process.monitor(conn_pid)
    stream_ref = :gun.post(conn_pid, to_charlist(query), headers, body)

    async_response(conn_pid, stream_ref, monitor_ref)
  end

  defp async_response(conn_pid, stream_ref, monitor_ref) do
    receive do
      {:gun_response, ^conn_pid, ^stream_ref, :fin, status, headers} ->
        %{status_code: status, body: "", headers: headers}

      {:gun_response, ^conn_pid, ^stream_ref, :nofin, status, headers} ->
        case receive_data(conn_pid, stream_ref, monitor_ref, "") do
          {:ok, data} ->
            %{status_code: status, body: data, headers: headers}
          {:error, reason} ->
            %{message: reason}
        end

      {:gun_error, ^conn_pid, ^stream_ref, reason} ->
        %{message: reason}
      {:gun_error, ^conn_pid, error} ->
        %{message: error}
      {:gun_down, ^conn_pid, _protocol, reason, _killed_streams, _unprocessed_streams} ->
        %{message: :gun_down}
      {:DOWN, ^monitor_ref, :process, ^conn_pid, reason} ->
        %{message: reason}
    after
      :timer.minutes(5) ->
        %{message: :recv_timeout}
    end
  end

  defp receive_data(conn_pid, stream_ref, monitor_ref, response_data) do
    receive do
      {:gun_data, ^conn_pid, ^stream_ref, :fin, data} ->
        {:ok, response_data <> data}
      {:gun_data, ^conn_pid, ^stream_ref, :nofin, data} ->
        receive_data(conn_pid, stream_ref, monitor_ref, response_data <> data)
      {:gun_down, ^conn_pid, _protocol, reason, _killed_streams, _unprocessed_streams} ->
        {:error, reason}
      {:DOWN, ^monitor_ref, :process, ^conn_pid, reason} ->
        {:error, reason}
    after
      :timer.minutes(5) ->
        {:error, :recv_timeout}
    end
  end

  defp convert_to_elixir(headers) do
    Enum.map headers, fn({name, value}) ->
      {name, to_charlist(value)}
    end
  end
end

{:ok, conn_pid} = HttpClient.connection("localhost", 8083)

Benchee.run(
  %{
    "open channels" => fn id ->
      HttpClient.post(conn_pid, "/ext/channel", "{}", %{
        "Content-Type" => "application/json",
        "application-id" => "x",
        "session-tracker" => id
      })
    end
  },
  before_each: fn (_) -> UUID.uuid4() end,
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

# Benchmarking open channels...

# Name                 ips        average  deviation         median         99th %
# open channels        5.26 K      190.08 μs  ±1177.23%      132.05 μs      241.53 μs

# Extended statistics:

# Name                minimum        maximum    sample size                     mode
# open channels       113.66 μs      103073 μs        41.76 K                125.46 μs
