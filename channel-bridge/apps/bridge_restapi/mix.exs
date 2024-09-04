defmodule BridgeApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :bridge_restapi,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger], mod: {BridgeApi, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bridge_core, in_umbrella: true},
      {:bridge_helper_config, in_umbrella: true},
      {:bridge_restapi_auth, in_umbrella: true},
      {:jason, "~> 1.4"},
      {:cowboy, "~> 2.10"},
      {:cowlib, "~> 2.12"},
      {:plug_cowboy, "~> 2.6"},
      {:plug_crypto, "~> 1.2"},
      {:cors_plug, "~> 3.0"},
      {:telemetry, "~> 1.0"},
      {:prometheus_ex, git: "https://github.com/lanodan/prometheus.ex", branch: "fix/elixir-1.14", override: true},
      {:prometheus_plugs, "~> 1.1"},
      ## == begin aws set of dependencies ==
      # {:ex_aws, "~> 2.2"},
      # {:ex_aws_sts, "~> 2.2"},
      # {:ex_aws_kms, "~> 2.2"},
      # {:configparser_ex, "~> 4.0"},
      # {:sweet_xml, "~> 0.6"},
      ## == end of aws set of dependencies ==
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end
end
