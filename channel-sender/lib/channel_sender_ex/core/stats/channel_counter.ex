defmodule ChannelSenderEx.Core.Stats.ChannelCounter do
  use GenServer

  alias ChannelSenderEx.Utils.CustomTelemetry

  @check_interval 5_000
  @initial_check 15_000

  # Public API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    initial_schedule()
    {:ok, %{cache_name: :channels}}
  end

  @impl true
  def handle_info(:check_cache_size, state) do
    size = length(:pg.which_groups())
    CustomTelemetry.execute_custom_event([:adf, :channel, :total], %{value: size})
    schedule_check()
    {:noreply, state}
  end

  # Helpers

  defp schedule_check do
    jitter = :rand.uniform(2_000)
    Process.send_after(self(), :check_cache_size, @check_interval + jitter)
  end

  defp initial_schedule do
    jitter = :rand.uniform(5_000)
    Process.send_after(self(), :check_cache_size, @initial_check + jitter)
  end
end
