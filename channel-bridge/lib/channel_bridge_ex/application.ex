defmodule ChannelBridgeEx.Application do
  @moduledoc false

  alias ChannelBridgeEx.ApplicationConfig
  alias ChannelBridgeEx.Entrypoint.Rest.BaseRouter
  alias ChannelBridgeEx.Boundary.ChannelSupervisor
  alias ChannelBridgeEx.Boundary.ChannelRegistry
  alias ChannelBridgeEx.Utils.ClusterUtils
  alias ChannelBridgeEx.Boundary.Telemetry.MetricsSetup
  alias Horde.DynamicSupervisor
  alias Horde.Registry, as: HordeRegistry

  use Application
  require Logger

  def start(_type, _args) do
    config = ApplicationConfig.load()

    ClusterUtils.discover_and_connect_local()

    # Start the Telemetry instrumenter
    MetricsSetup.setup()

    # Start poison and its dependencies
    HTTPoison.start()

    # ChannelBridgeEx.Core.RulesProvider.Helper.compile(:channel_bridge_ex)
    opts = [strategy: :one_for_one, name: ChannelBridgeEx.Supervisor]
    Supervisor.start_link(children(config), opts)
  end

  defp children(config) do
    [
      #{AdfSenderConnector, [name: :adf_sender, sender_url: get_in(config, [:sender, "rest_endpoint"]) ]},
      AdfSenderConnector.spec([sender_url: get_in(config, [:sender, "rest_endpoint"])]),
      AdfSenderConnector.registry_spec(),
      ChannelBridgeEx.Adapter.Store.Cache.worker_spec([
        get_in(config, [:bridge, "cache_expiration"])
      ]),
      {HordeRegistry, name: ChannelRegistry, keys: :unique, members: :auto},
      {DynamicSupervisor, name: ChannelSupervisor, strategy: :one_for_one, members: :auto},
      # {ChannelBridgeEx.Entrypoint.Pubsub.Amqp.AMQPSubscriber, [ApplicationConfig.get_rabbitmq_config(config)]},
      EventBusAmqp.build_child_spec(ApplicationConfig.get_rabbitmq_config(config)),
      # EventBusSqs.build_child_spec(ApplicationConfig.get_sqs_config(config)),
      {Task.Supervisor, name: ADFSender.TaskSupervisor},
      # :poolboy.child_spec(:homologation_worker, homologation_workers_config()),
      {Plug.Cowboy,
       scheme: :http,
       plug: BaseRouter,
       options: [
         port: get_in(config, [:bridge, "rest_port"]),
         protocol_options: [max_keepalive: 2_000, active_n: 200]
       ]}
    ]
  end

  # defp homologation_workers_config() do
  #   [
  #     name: {:local, :homologation_worker},
  #     worker_module: ChannelBridgeEx.Adapter.ErrorHomologation.RestAdapter,
  #     size: 5,
  #     max_overflow: 2
  #   ]
  # end
end
