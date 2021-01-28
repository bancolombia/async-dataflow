defmodule ChannelSenderEx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  alias ChannelSenderEx.Transport.Rest.RestController
  alias ChannelSenderEx.Transport.EntryPoint
  alias ChannelSenderEx.Core.ChannelSupervisor
  alias ChannelSenderEx.Core.ChannelRegistry
  import Telemetry.Metrics

  use Application

  @supervisor_module Application.get_env(:channel_sender_ex, :channel_supervisor_module)
  @registry_module Application.get_env(:channel_sender_ex, :registry_module)
  @no_start Application.get_env(:channel_sender_ex, :no_start)

  def start(_type, _args) do
    ChannelSenderEx.Utils.ClusterUtils.discover_and_connect_local()
    ChannelSenderEx.Core.RulesProvider.Helper.compile(:channel_sender_ex)

    if !@no_start do
      EntryPoint.start()
    end

    opts = [strategy: :one_for_one, name: ChannelSenderEx.Supervisor]
    Supervisor.start_link(children(@no_start), opts)
  end

  defp children(_no_start = false) do
    http_port = Application.get_env(:channel_sender_ex, :rest_port, 8080)
    [
      {@registry_module, name: ChannelRegistry, keys: :unique, members: :auto},
      {:telemetry_poller, measurements: [
              {:process_info, name: ChannelSenderEx.Core.ChannelSupervisor, event: [:app, :chan_sup], keys: [:memory, :message_queue_len]},
              {:process_info, name: ChannelSenderEx.Core.ChannelRegistry, event: [:app, :chan_reg], keys: [:memory, :message_queue_len]}
      ], period: 5_000},
      {TelemetryMetricsPrometheus, [metrics: metrics()]},
      {@supervisor_module, name: ChannelSupervisor, strategy: :one_for_one, members: :auto},
      {Plug.Cowboy, scheme: :http, plug: RestController, options: [port: http_port]}
    ]
  end

  defp children(_no_start = true), do: []

  def metrics() do
    [
      last_value("vm.memory.total", unit: :byte),
      last_value("vm.memory.processes", unit: :byte),
      last_value("vm.memory.code", unit: :byte),
      last_value("vm.memory.processes_used", unit: :byte),
      last_value("vm.memory.system", unit: :byte),
      last_value("vm.memory.atom", unit: :byte),
      last_value("vm.memory.atom_used", unit: :byte),
      last_value("vm.memory.binary", unit: :byte),
      last_value("vm.memory.ets", unit: :byte),

      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.total_run_queue_lengths.io"),

      last_value("vm.system_counts.process_count"),
      last_value("vm.system_counts.atom_count"),
      last_value("vm.system_counts.port_count"),

      last_value("app.chan_sup.memory"),
      last_value("app.chan_sup.message_queue_len"),
      last_value("app.chan_reg.memory"),
      last_value("app.chan_reg.message_queue_len"),

    ]
  end

end

defmodule MemInfo do
  def get_metrics() do
    Process.list() |> Enum.map(fn pid ->
      {
        Process.info(pid, :memory) |> elem(1),
        Process.info(pid, :registered_name),
        Process.info(pid, :message_queue_len),
        Process.info(pid, :reductions),
        pid
      }
    end)
    |> Enum.sort_by(fn {mem, _, _, _, _} -> mem end)
    |> Enum.reverse()
    |> Enum.take(5)
    |> Enum.map(fn info ->
      pid = elem(info, 4)
      {:message_queue_len, queue} = elem(info, 2)
      state_size = cond do
        queue < 200 ->
          try do
            (:sys.get_state(pid, 500) |> :erlang.term_to_binary() |> byte_size())
          catch
            :exit, _ -> 0
            _, _ -> 0
          end
        true -> 0
      end
      Tuple.insert_at(info, 1, {:state_size, state_size})
    end)

  end
end
