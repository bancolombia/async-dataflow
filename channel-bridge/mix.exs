defmodule ChannelBridgeEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :channel_bridge_ex,
      version: "0.0.1",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [
        tool: ExCoveralls
      ],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.xml": :test
      ],
      aliases: aliases(),
      releases: [
        channel_bridge_ex: [
          include_executables_for: [:unix],
          applications: [
            runtime_tools: :permanent
          ],
          steps: [:assemble, :tar]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:lager, :logger],
      mod: {ChannelBridgeEx.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:lager, "~> 3.2"},
      {:uuid, "~> 1.1"},
      {:cowboy, "~> 2.8"},
      {:cowlib, "~> 2.9", override: true},
      {:plug_cowboy, "~> 2.4.1"},
      {:plug_crypto, "~> 1.1"},
      {:cors_plug, "~> 2.0"},
      {:poolboy, "~> 1.5.1"},
      {:gen_state_machine, "~> 2.1"},
      ## == json handling ==
      {:jason, "~> 1.2"},
      {:json_xema, "~> 0.6.0"},
      {:exjsonpath, "~> 0.1"},
      {:odgn_json_pointer, "~> 3.0.1"},
      {:jose, "~> 1.11.1"},
      {:morphix, "~>0.8.1"},
      {:horde, "~> 0.8.3"},
      {:httpoison, "~> 1.8"},
      {:event_bus_amqp, path: "./apps/event_bus_amqp"},
      {:jwt_support, path: "./apps/jwt_support"},
      # Pending connector publication in hex.pm
      {:adf_sender_connector, path: "../clients/backend-client-elixir"},
      # Observability dependencies
      {:telemetry, "~> 0.4.2"},
      #{:prometheus_ex, "~> 3.0.5"}, # waiting for a fix on elixir 1.14
      {:prometheus_ex, git: "https://github.com/lanodan/prometheus.ex", branch: "fix/elixir-1.14", override: true},
      {:prometheus_plugs, "~> 1.1.1"},
      # library for configuration via yaml
      {:vapor, "~> 0.10.0"},
      # testing dependencies
      {:stream_data, "~> 0.4", only: [:test]},
      {:gun, "~> 1.3", only: [:test, :dev, :benchee]},
      {:mock, "~> 0.3.0", only: :test},
      {:benchee, "~> 0.13", only: [:dev, :benchee]},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:credo_sonarqube, "~> 0.1.3", only: [:dev, :test]},
      {:sobelow, "~> 0.8", only: :dev},
      {:excoveralls, "~> 0.10", only: :test},
      {:ex_unit_sonarqube, "~> 0.1", only: :test}
    ]
  end

  defp aliases do
    [test: "test --no-start"]
  end

  defp elixirc_paths(:test), do: ["lib", "test"]
  defp elixirc_paths(_), do: ["lib"]
end
