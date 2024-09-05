defmodule BridgeCore do
  @moduledoc """
  Documentation for `BridgeCore`.
  """
  use Application

  require Logger

  alias BridgeCore.Channel
  alias BridgeCore.CloudEvent

  alias BridgeCore.Boundary.ChannelManager
  alias BridgeCore.Boundary.ChannelRegistry
  alias BridgeCore.Boundary.ChannelSupervisor
  alias BridgeCore.Boundary.NodeObserver

  alias BridgeCore.Sender.Connector

  @default_mutator %{
    "mutator_module" => "Elixir.BridgeCore.CloudEvent.Mutator.DefaultMutator",
    "config" => nil
  }

  @doc false
  @impl Application
  def start(_type, _args) do

    sender_url_cfg = BridgeHelperConfig.get([:sender, "url"], "http://localhost:8081")

    children = case (Application.get_env(:bridge_core, :env)) do
      e when e in [:test, :bench] ->
        Logger.debug("Running in test mode")
        [
          {Task.Supervisor, name: BridgeCore.TaskSupervisor},
          AdfSenderConnector.spec([sender_url: sender_url_cfg]),
          AdfSenderConnector.registry_spec(),
        ]

      _ ->
        Logger.debug("Running in production mode")
        [
          {Task.Supervisor, name: BridgeCore.TaskSupervisor},
          {Cluster.Supervisor, [topologies(), [name: BridgeCore.ClusterSupervisor]]},
          ChannelRegistry,
          ChannelSupervisor,
          NodeObserver,
          AdfSenderConnector.spec([sender_url: sender_url_cfg]),
          AdfSenderConnector.registry_spec(),
        ]
    end

    opts = [strategy: :one_for_one, name: BridgeCore.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Starts a session given a channel and a list of options.
  """
  @spec start_session(Channel.t(), list()) :: {:ok, {Channel.t(), any()}} | {:error, any()}
  def start_session(channel, _options \\ []) do
    case lookup_channel_pid(channel.channel_alias) do
      {:error, :noproc} ->
        channel_registration = obtain_credentials(channel)
        case channel_registration do
          {:ok, registered_channel} ->

            mutator_setup = BridgeHelperConfig.get([:bridge, "cloud_event_mutator"], @default_mutator)
            ChannelSupervisor.start_channel_process(
              registered_channel,
              mutator_setup
            )

            {:ok, {registered_channel, mutator_setup}}

          {:error, _reason} = err ->
            err
        end

      {:ok, pid} ->
        # channel process already exists
        Logger.debug("Channel already registered with alias : #{channel.channel_alias}")

        {:ok, {existing_channel, mutator}} = ChannelManager.get_channel_info(pid)
        existing_channel_with_new_credentials = obtain_credentials(existing_channel)
        case existing_channel_with_new_credentials do
          {:ok, registered_channel} ->

            ChannelSupervisor.start_channel_process(
              registered_channel,
              mutator
            )

            {:ok, {registered_channel, mutator}}

          {:error, _reason} = err ->
            err
        end

    end
  end

  @spec route_message(String.t, CloudEvent.t) :: :ok | {:error, any}
  def route_message(channel_alias, cloud_event) do
    case lookup_channel_pid(channel_alias) do
      {:error, :noproc} ->
        {:error, :noproc}
      {:ok, pid} ->
        ChannelManager.deliver_message(pid, cloud_event)
    end
  end

  @spec end_session(String.t) :: :ok | {:error, any}
  def end_session(channel_alias) do
    case lookup_channel_pid(channel_alias) do
      {:error, :noproc} = err ->
        err
      {:ok, pid} ->
        ChannelManager.close_channel(pid)
    end
  end

  defp obtain_credentials(channel) do
    Task.Supervisor.async(BridgeCore.TaskSupervisor, fn ->
      case Connector.channel_registration(channel.application_ref.id, channel.user_ref.id) do
        {:ok, creds} ->
          {:ok, Channel.update_credentials(channel, creds["channel_ref"], creds["channel_secret"]) }
        {:error, _reason} = err ->
            err
        end
      end)
    |> Task.await()
  end

  defp lookup_channel_pid(channel_alias) do
    case ChannelRegistry.lookup_channel_addr(channel_alias) do
      :noproc ->
        {:error, :noproc}

      pid ->
        {:ok, pid}
    end
  end

  def topologies do
    topology = [
      k8s: parse_libcluster_topology()
    ]
    topology
  end

  defp parse_libcluster_topology do
    topology = BridgeHelperConfig.get([:bridge, "topology"], nil)
    case topology do
      nil ->
        Logger.warning("No libcluster topology defined!!! -> Using Default [Gossip]")
        [strategy: Cluster.Strategy.Gossip]
      _ ->
        [
          strategy: String.to_existing_atom(topology["strategy"]),
          config: parse_config_key(topology["config"])
        ]
    end
  end

  defp parse_config_key(cfg) do
    case cfg do
      nil ->
        []
      _ ->
        Enum.map(cfg, fn({key, value}) ->
          {String.to_atom(key), process_param(value)}
        end)
    end
  end

  defp process_param(param) when is_integer(param) do
    param
  end

  defp process_param(param) when is_binary(param) do
    case String.starts_with?(param, ":") do
      true ->
        String.to_atom(String.replace_leading(param, ":", ""))
      false ->
        param
    end
  end
end
