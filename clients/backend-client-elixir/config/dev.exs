import Config

config :adf_sender_connector,
  base_path: "http://localhost:8081",
  conn_pools: 1,
  pool_size: 20,
  conn_max_idle_time: 60_000

config :logger, level: :info
