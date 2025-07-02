import Config

config :channel_sender_ex,
  secret_base:
    {"aV4ZPOf7T7HX6GvbhwyBlDM8B9jfeiwi+9qkBnjXxUZXqAeTrehojWKHkV3U0kGc", "socket auth"},
  initial_redelivery_time: 100,
  app_repo: ChannelSenderEx.Repository.ApplicationRepo,
  channel_shutdown_tolerance: 10_000,
  max_age: 900,
  socket_idle_timeout: 60000,
  socket_port: 8082,
  rest_port: 8081,
  topology: [
    strategy: Cluster.Strategy.Gossip
  ]

config :opentelemetry,
  span_processor: :batch,
  traces_exporter: {:otel_exporter_stdout, []}

config :opentelemetry_plug,
  ignored_routes: ["/health", "/metrics"]
