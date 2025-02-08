defmodule ChannelSenderEx.Core.NodeObserver do
  @moduledoc false

  use GenServer

  alias ChannelSenderEx.Core.{ChannelRegistry, ChannelSupervisor}

  def start_link(_), do: GenServer.start_link(__MODULE__, [])

  def init(_) do
    :net_kernel.monitor_nodes(true, node_type: :visible)
    {:ok, nil}
  end

  def handle_info({:nodeup, _node, _node_type}, state) do
    set_members(ChannelRegistry)
    set_members(ChannelSupervisor)
    {:noreply, state}
  end

  def handle_info({:nodedown, _node, _node_type}, state) do
    set_members(ChannelRegistry)
    set_members(ChannelSupervisor)
    {:noreply, state}
  end

  defp set_members(name) do
    members =
      [Node.self() | Node.list()]
      |> Enum.map(fn node -> {name, node} end)
    :ok = Horde.Cluster.set_members(name, members)
  end
end
