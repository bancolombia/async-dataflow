defmodule BridgeCore do
  @moduledoc """
  Documentation for `BridgeCore`.
  """
  use Application

  require Logger

  alias BridgeCore.CloudEvent
  alias BridgeCore.Channel
  # alias BridgeCore.AppClient
  # alias BridgeCore.User
  alias BridgeCore.Boundary.ChannelSupervisor
  alias BridgeCore.Boundary.ChannelManager
  alias BridgeCore.Boundary.ChannelRegistry
  alias BridgeCore.Boundary.NodeObserver

  @default_mutator "Elixir.BridgeCore.CloudEvent.Mutator.DefaultMutator"

  @doc false
  @impl Application
  def start(_type, _args) do

    sender_url_cfg = BridgeHelperConfig.get([:sender, "url"], "http://localhost:8081")

    children = case (Application.get_env(:bridge_core, :env)) do
      e when e in [:test, :bench] ->
        [
          {Task.Supervisor, name: BridgeCore.TaskSupervisor},
          AdfSenderConnector.spec([sender_url: sender_url_cfg]),
          AdfSenderConnector.registry_spec(),
        ]

      _ ->
        [
          {Task.Supervisor, name: BridgeCore.TaskSupervisor},
          # {Cluster.Supervisor, [topologies(), [name: BridgeCore.ClusterSupervisor]]},
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

  # @doc """
  # Starts a session given a channel alias, an application referenca and a user rerefence.
  # """
  # @spec start_session(binary(), binary(), binary()) :: {:ok, {Channel.t(), atom()}} | {:error, any()}
  # def start_session(channel_alias, application_ref, user_ref) do
  #   start_session(
  #     Channel.new(channel_alias, AppClient.new(application_ref, ""), User.new(user_ref)),
  #     []
  #   )
  # end

  @doc """
  Starts a session given a channel and a list of options.
  """
  @spec start_session(Channel.t(), list()) :: {:ok, {Channel.t(), any()}} | {:error, any()}
  def start_session(channel, _options \\ []) do
    # TODO use an option to force register new session
    case lookup_channel_pid(channel.channel_alias) do
      {:error, :noproc} ->
        channel_registration = obtain_credentials(channel)
        case channel_registration do
          {:ok, registered_channel} ->
            mutator = String.to_existing_atom(
              BridgeHelperConfig.get([:bridge, "cloud_event_mutator"], @default_mutator)
            )
            ChannelSupervisor.start_channel_process(
              registered_channel,
              mutator
            )
            {:ok, {registered_channel, mutator}}

          {:error, _reason} = err ->
            err
        end
      {:ok, pid} ->
        # Logger.warning("Channel process already exists for alias #{inspect(channel.channel_alias)}")
        ChannelManager.get_channel_info(pid)
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
      with {:ok, creds} <- AdfSenderConnector.channel_registration(channel.application_ref.id, channel.user_ref.id)
      do
        {:ok, Channel.update_credentials(channel, creds["channel_ref"], creds["channel_secret"]) }
      else
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

end
