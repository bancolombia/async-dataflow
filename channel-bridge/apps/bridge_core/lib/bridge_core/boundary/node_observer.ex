defmodule BridgeCore.Boundary.NodeObserver do
  @moduledoc """
  Observes the nodes in the cluster and updates the members of the cluster.
  """
    use GenServer

    alias BridgeCore.Boundary.{ChannelRegistry, ChannelSupervisor}

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
      members = Enum.map([Node.self() | Node.list()], &{name, &1})

      :ok = Horde.Cluster.set_members(name, members)
    end
  end
