defmodule ChannelSenderEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :channel_sender_ex,
      version: "0.2.5",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: [
        channel_sender_ex: [
          include_executables_for: [:unix],
          applications: [runtime_tools: :permanent],
          steps: [:assemble, :tar]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    extra_apps =
      if Mix.env() == :dev do
        [
          :logger,
          :telemetry,
          :observer,
          :wx,
          :runtime_tools,
          :opentelemetry_exporter,
          :opentelemetry
        ]
      else
        [:logger, :telemetry, :opentelemetry_exporter, :opentelemetry]
      end

    [
      extra_applications: extra_apps,
      mod: {ChannelSenderEx.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      {:benchee, "~> 0.13", only: [:dev, :benchee]},
      {:cowboy, "~> 2.8"},
      {:cowlib, "~> 2.9", override: true},
      {:plug_cowboy, "~> 2.0"},
      {:elixir_uuid, "~> 1.2"},
      {:gen_state_machine, "~> 2.0"},
      {:jason, "~> 1.2"},
      {:cors_plug, "~> 3.0"},
      {:hackney, "~> 1.20.1", only: :test},
      {:plug_crypto, "~> 2.1"},
      {:stream_data, "~> 0.4", only: [:test]},
      {:gun, "~> 1.3", only: [:test, :benchee]},
      {:libcluster, "~> 3.4.1"},
      {:vapor, "~> 0.10.0"},
      {:mock, "~> 0.3.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      # for metrics
      {:telemetry_metrics_prometheus, "~> 1.1"},
      {:telemetry_poller, "~> 1.1"},
      {:cowboy_telemetry, "~> 0.4.0"},
      {:telemetry, "~> 1.3"},
      {:opentelemetry, "~> 1.5"},
      {:opentelemetry_exporter, "~> 1.8"},
      {:opentelemetry_api, "~> 1.4"},
      {:opentelemetry_plug,
       git: "https://github.com/bancolombia/opentelemetry_plug.git", tag: "v1.1.1"},
      {:eflambe, "~> 0.3.0"},
      {:meck, "0.9.2"},
      {:observer_cli, "~> 1.8"}
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp aliases do
    [test: "test --no-start"]
  end
end
