import Config

config :bridge_core, env: Mix.env()

config :logger, :default_formatter,
  format: "\n$time [$level][$metadata] $message\n",
  metadata: [:application]
