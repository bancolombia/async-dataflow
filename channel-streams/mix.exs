defmodule ChannelStreams.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.2.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        adf_streams: [
          applications: [
            streams_helper_config: :permanent,
            streams_core: :permanent,
            streams_rabbitmq: :permanent,
            streams_secretmanager: :permanent,
            streams_restapi: :permanent,
            streams_restapi_auth: :permanent
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
