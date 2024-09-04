defmodule ChannelBridge.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.2.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        adf_bridge: [
          applications: [
            bridge_helper_config: :permanent,
            bridge_core: :permanent,
            bridge_rabbitmq: :permanent,
            bridge_secretmanager: :permanent,
            bridge_restapi: :permanent,
            bridge_restapi_auth: :permanent
          ]
        ],
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.xml": :test,
        "coveralls.github": :test,
        "coveralls.lcov": :test
      ]
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:excoveralls, "~> 0.18", [only: [:dev, :test]]}
    ]
  end
end
