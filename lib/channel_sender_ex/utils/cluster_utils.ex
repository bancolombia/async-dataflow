defmodule ChannelSenderEx.Utils.ClusterUtils do
  @moduledoc """
  Utilities for clustering and distributed capacities and verifications (Testing)
  """
  require Logger

  def discover_and_connect_local() do
    [node_name, host] = node()
    |> Atom.to_string()
    |> String.split("@")

    case String.split(node_name, "-") do
      [prefix, _name] -> discover_and_connect(host, prefix)
      name -> Logger.warn("Node name has the incorrect format for auto discovery: #{name}")
    end
    
  end

  def discover_and_connect(epmd_host, prefix) do
    nodes_to_connect = case :erl_epmd.names(String.to_atom(epmd_host)) do
      {:ok, nodes} ->
        nodes
        |> Enum.map(&:erlang.list_to_binary(elem(&1, 0)))
        |> Enum.filter(&String.starts_with?(&1, prefix))
      error ->
        Logger.warn("EPMD error in node discovery", error)
        []
    end

    nodes_to_connect
    |> Enum.each(fn name ->
      full_name = :erlang.binary_to_atom("#{name}@#{epmd_host}")
      if full_name != node() do
        result = Node.connect(full_name)
        Logger.info("Connected to node: #{inspect(full_name)}, #{inspect(result)}")
      end
    end)

  end
end
