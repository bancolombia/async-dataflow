import Config

config :channel_sender_ex,
  channel_supervisor_module: Horde.DynamicSupervisor,
  registry_module: Horde.Registry,
  app_repo: ChannelSenderEx.Repository.ApplicationRepo,
  channel_shutdown_tolerance: 10_000,
  no_start: false,
  socket_event_bus: ChannelSenderEx.Core.PubSub.SocketEventBus

import_config "#{Mix.env()}.exs"
