import Config

config :channel_bridge_ex,
  channel_supervisor_module: Horde.DynamicSupervisor,
  registry_module: Horde.Registry,
  amqp_producer_module: Broadway.DummyProducer,
  validate_header_keys_during_test: false,
  broker_queue: "adf_bridge_ex_queue",
  channel_authenticator: ChannelBridgeEx.Core.Auth.JwtParseOnly,
  cache_expiration: 1,
  rest_port: 8081

config :logger, level: :info

config :plug, :validate_header_keys_during_test, false
