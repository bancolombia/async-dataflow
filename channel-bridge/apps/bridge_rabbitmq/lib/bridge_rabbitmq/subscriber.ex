defmodule BridgeRabbitmq.Subscriber do
  @moduledoc """
    Module entrypoint for messages received via RabbitMQ
  """
  use Broadway

  require Logger

  alias BridgeCore.CloudEvent.RoutingError

  alias BridgeRabbitmq.MessageProcessor

  def start_link(opts) do
    config = List.first(opts)
    Logger.debug("Starting RabbitMQ Producer Module")

    Broadway.start_link(__MODULE__,
      name: get_registration_name(config),
      producer: [
        module:
          {get_producer_module(config),
            queue: get_in(config, ["queue"]),
            connection: get_in(config, ["broker_url"]),
            name: "channel-bridge-listener",
            qos: [
              prefetch_count: get_in(config, ["producer_prefetch"])
            ],
            declare: [durable: true],
            bindings: process_bindings(get_in(config, ["bindings"])),
            on_success: :ack,
            on_failure: :reject_and_requeue_once,
            after_connect: &declare_rabbitmq_topology/1,
            metadata: []
          },
        concurrency: get_in(config, ["producer_concurrency"])
        # rate_limiting: [
        #   allowed_messages: 1,
        #   interval: 100
        # ],
      ],
      processors: [
        default: [
          concurrency: get_in(config, ["processor_concurrency"]),
          max_demand: get_in(config, ["processor_max_demand"])
        ]
      ]
    )
  end

  def stop do
    Logger.debug("Stopping RabbitMQ Producer Module")
    Broadway.stop(__MODULE__, :normal)
  end

  defp declare_rabbitmq_topology(amqp_channel) do
    AMQP.Exchange.declare(amqp_channel, "domainEvents", :topic, durable: true)
  end

  @impl true
  def handle_message(_, message, _context) do
    try do
      message.data
      |> MessageProcessor.handle_message
    rescue
      e in RoutingError ->
        Logger.error("Error processing message: #{inspect(e)}")
    end

    message
  end

  defp process_bindings(bindings) do
    case bindings do
      nil ->
        []
      _ ->
        Enum.map(bindings, fn e ->
          {get_in(e, ["name"]), [routing_key: List.first(get_in(e, ["routing_key"]))]}
        end)
    end

  end

  defp get_registration_name(config) do
    case get_in(config, ["producer_name"]) do
      nil ->
        __MODULE__
      value ->
        String.to_atom(value)
    end
  end

  defp get_producer_module(config) do
    case get_in(config, ["producer_module"]) do
      nil ->
        BroadwayRabbitMQ.Producer
      producer ->
        Module.safe_concat([producer])
    end
  end

end
