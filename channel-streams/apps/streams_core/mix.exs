defmodule StreamsCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :streams_core,
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
      extra_applications: [:logger], mod: {StreamsCore, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:streams_helper_config, in_umbrella: true},
      {:gen_state_machine, "~> 3.0"},
      {:uuid, "~> 1.1"},
      {:jason, "~> 1.2"},
      {:json_xema, "~> 0.6.0"},
      {:morphix, "~>0.8.1"},
      {:exjsonpath, "~> 0.1"},
      {:horde, "~> 0.8.3"},
      {:libcluster, "~> 3.3"},
      {:adf_sender_connector, git: "https://github.com/bancolombia/async-dataflow",
        sparse: "clients/backend-client-elixir", branch: "master",
        override: true},
      {:mock, "~> 0.3.8", only: :test},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end
end
