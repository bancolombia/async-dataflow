defmodule BridgeRabbitmq.MixProject do
  use Mix.Project

  def project do
    [
      app: :bridge_rabbitmq,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger], mod: {BridgeRabbitmq.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bridge_core, in_umbrella: true},
      {:bridge_helper_config, in_umbrella: true},
      {:bridge_secretmanager, in_umbrella: true},
      {:broadway_rabbitmq, "~> 0.7.0"},
      {:ex_aws, "~> 2.2"},
      {:ex_aws_sts, "~> 2.2"},
      {:ex_aws_secretsmanager, "~> 2.0"},
      {:configparser_ex, "~> 4.0"},
      {:sweet_xml, "~> 0.6"},
      {:vapor, "~> 0.10.0"},
      # testing dependencies
      {:mock, "~> 0.3.8", only: :test},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:credo_sonarqube, "~> 0.1.3", only: [:dev, :test]},
      {:sobelow, "~> 0.8", only: :dev},
      {:excoveralls, "~> 0.10", only: :test},
      {:ex_unit_sonarqube, "~> 0.1", only: :test}
    ]
  end
end
