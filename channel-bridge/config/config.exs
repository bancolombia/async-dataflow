import Config

config :channel_bridge_ex,
  channel_authenticator: ChannelBridgeEx.Core.Auth.PassthroughAuth,
  cache_repo: ChannelBridgeEx.Adapter.Store.Cache,
  amqp_producer_module: BroadwayRabbitMQ.Producer

import_config "#{Mix.env()}.exs"
