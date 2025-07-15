defmodule ChannelSenderEx.Utils.ChannelMetrics do
  @moduledoc """
  A GenServer that tracks the number of active channels in the system.
  """
  use GenServer
  alias ChannelSenderEx.Utils.CustomTelemetry
  require Logger

  def start_link(_args), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def get_count, do: GenServer.call(__MODULE__, :get)

  @impl true
  def init(_) do
    schedule_update()
    send_metric(0)
    {:ok, %{count: 0}}
  end

  @impl true
  def handle_call(:get, _from, state), do: {:reply, state.count, state}

  @impl true
  def handle_info(:update, state) do
    count =
      :pg.which_groups()
      |> Enum.count()

    send_metric(count)
    schedule_update()
    {:noreply, %{state | count: count}}
  end

  defp schedule_update do
    interval_minutes =
      Application.get_env(:channel_sender_ex, :interval_minutes_count_active_channel, 2)

    interval_ms = :timer.minutes(interval_minutes)
    Process.send_after(self(), :update, interval_ms)
  end

  defp send_metric(count) do
    CustomTelemetry.execute_custom_event(
      [:adf, :channel, :active],
      %{count: count}
    )
  end
end
