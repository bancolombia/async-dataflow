defmodule ChannelSenderEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :channel_sender_ex,
      version: "0.1.0",
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
    extra_apps = if Mix.env() == :dev do
      [:logger, :telemetry, :observer, :wx, :runtime_tools]
    else
      [:logger, :telemetry]
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
      {:cowboy, "~> 2.13"},
      {:cowlib, "~> 2.14", override: true},
      {:plug_cowboy, "~> 2.7"},
      {:elixir_uuid, "~> 1.2"},
      {:gen_state_machine, "~> 3.0"},
      {:jason, "~> 1.4"},
      {:cors_plug, "~> 3.0"},
      {:horde, "~> 0.9"},
      {:plug_crypto, "~> 2.1"},
      {:finch, "~> 0.19"},
      {:libcluster, "~> 3.5"},
      {:vapor, "~> 0.10"},
      {:aws_signature, "~> 0.3"},
      {:ex_aws, "~> 2.5"},
      {:ex_aws_sts, "~> 2.3"},
      {:ex_aws_secretsmanager, "~> 2.0"},
      {:sweet_xml, "~> 0.7"},
      {:configparser_ex, "~> 4.0"},
      {:redix, "~> 1.5"},
      {:poolboy, "~> 1.5"},
      # for metrics
      {:telemetry_metrics_prometheus, "~> 1.1"},
      {:telemetry_poller, "~> 1.1"},
      {:cowboy_telemetry, "~> 0.4"},
      {:telemetry, "~> 1.3"},
      # for testing
      {:hackney, "~> 1.23", only: :test},
      {:stream_data, "~> 1.1", only: [:test]},
      {:benchee, "~> 1.3", only: [:dev, :benchee]},
      {:gun, "~> 2.1", only: [:test, :benchee]},
      {:mock, "~> 0.3", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp aliases do
    [test: "test --no-start"]
  end
end
