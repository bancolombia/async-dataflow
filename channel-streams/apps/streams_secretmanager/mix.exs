defmodule StreamsSecretManager.MixProject do
  use Mix.Project

  def project do
    [
      app: :streams_secretmanager,
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
      extra_applications: [:logger],
      mod: {StreamsSecretManager.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:streams_helper_config, in_umbrella: true},
      {:ex_aws, "~> 2.2"},
      {:ex_aws_sts, "~> 2.2"},
      {:ex_aws_secretsmanager, "~> 2.0"},
      # test only dependencies
      {:mock, "~> 0.3.8", only: :test},
    ]
  end
end
