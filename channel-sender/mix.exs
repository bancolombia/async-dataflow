defmodule ChannelSenderEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :channel_sender_ex,
      version: "0.3.2",
      elixir: "~> 1.19",
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
        [:logger, :gproc, :observer, :wx, :runtime_tools]
      else
        [:logger, :gproc]
      end

    optionals = [
      telemetry: :optional,
      opentelemetry: :optional,
      opentelemetry_exporter: :optional
    ]

    [
      extra_applications: extra_apps ++ optionals,
      include_applications: [:telemetry, :opentelemetry_exporter, :opentelemetry],
      mod: {ChannelSenderEx.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:cors_plug, "~> 3.0"},
      {:cowboy, "~> 2.14"},
      {:cowlib, "~> 2.16"},
      {:elixir_uuid, "~> 1.2"},
      {:gen_state_machine, "~> 3.0"},
      {:jason, "~> 1.4"},
      {:libcluster, "~> 3.5"},
      {:plug_cowboy, "~> 2.7"},
      {:plug_crypto, "~> 2.1"},
      {:vapor, "~> 0.10"},
      # for metrics and tracing
      {:opentelemetry, "~> 1.7"},
      {:opentelemetry_exporter, "~> 1.10"},
      {:opentelemetry_api, "~> 1.5"},
      {:opentelemetry_plug,
       git: "https://github.com/bancolombia/opentelemetry_plug.git", tag: "v1.3.0"},
      {:opentelemetry_semantic_conventions, "~> 1.27"},
      {:cowboy_telemetry, "~> 0.4"},
      {:telemetry, "~> 1.3"},
      {:telemetry_metrics_prometheus, "~> 1.1"},
      {:telemetry_poller, "~> 1.3"},
      # Profiling tools
      {:eflambe, "~> 0.3"},
      {:observer_cli, "~> 1.8"},
      # Dev and Test dependencies
      # {:meck, "0.9.2"},
      {:hackney, "~> 1.25", only: :test},
      {:stream_data, "~> 1.2", only: :test},
      {:mock, "~> 0.3", only: :test},
      {:benchee, "~> 1.5", only: [:dev, :benchee]},
      {:gun, "~> 2.2", only: [:test, :benchee]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end

  defp aliases do
    [test: "test --no-start"]
  end
end
