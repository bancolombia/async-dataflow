defmodule EventBusAmqp.Subscriber do
  @moduledoc """
    Module entrypoint for messages received via RabbitMQ
  """
  use Broadway
  require Logger

  def start_link(opts) do
    config = List.first(opts)

    Broadway.start_link(__MODULE__,
      name: get_registration_name(config),
      producer: [
        module:
          {get_producer_module(config),
           queue: get_in(config, ["broker_queue"]),
           connection: get_in(config, ["broker_url"]),
           name: "channel-bridge listener",
           qos: [
             prefetch_count: get_in(config, ["broker_producer_prefetch"])
           ],
           declare: [durable: true],
           bindings: get_in(config, ["broker_bindings"]),
           on_success: :ack,
           on_failure: :reject_and_requeue_once,
           metadata: []},
        concurrency: get_in(config, ["broker_producer_concurrency"])
        # rate_limiting: [
        #   allowed_messages: 1,
        #   interval: 100
        # ],
      ],
      processors: [
        default: [
          concurrency: get_in(config, ["broker_processor_concurrency"]),
          max_demand: get_in(config, ["broker_processor_max_demand"])
        ]
      ],
      context: [
        handle_message_fn: case get_in(config, ["handle_message_fn"]) do
          nil -> fn(a) -> :ok end
          fun -> fun
        end
      ]
    )
  end

  @impl true
  def handle_message(_, message, context) do
    fun = Keyword.fetch!(context, :handle_message_fn)

    message.data
    |> fun.()

    message
  end

  defp get_registration_name(config) do
    case get_in(config, ["broker_producer_name"]) do
      nil ->
        __MODULE__
      value ->
        String.to_atom(value)
    end
  end

  defp get_producer_module(config) do
    case get_in(config, ["broker_producer_module"]) do
      nil ->
        Logger.debug("Using default RabbitMQ Producer Module")
        BroadwayRabbitMQ.Producer
      producer ->
        Logger.debug("Using RabbitMQ Producer Module: #{producer}")
        Module.safe_concat([producer])
    end
  end

end
