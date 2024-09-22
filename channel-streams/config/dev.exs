import Config

config :streams_core,
  env: Mix.env(),
  config_file: "./config-local.yaml"

config :logger, :default_formatter,
  format: "\n$time [$level][$metadata] $message\n",
  metadata: [:application]
