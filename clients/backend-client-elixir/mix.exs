defmodule AdfSenderConnector.MixProject do
  use Mix.Project

  @version "0.4.0"

  def project do
    [
      app: :adf_sender_connector,
      version: @version,
      elixir: "~> 1.16",
      docs: [
        extras: ["README.md"],
        main: "readme",
        source_ref: "v#{@version}"
      ],
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
        adf_sender_connector: [
          include_executables_for: [:unix],
          applications: [
            runtime_tools: :permanent
          ],
          steps: [:assemble, :tar]
        ]
      ],
      package: package(),
      description: description(),
      source_url:
        "https://github.com/bancolombia/async-dataflow/tree/master/clients/backend-client-elixir"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.2"},
      {:finch, "~> 0.19"},
      {:uuid, "~> 1.1"},
      # traces
      {:opentelemetry_api, "~> 1.0"},
      ## testing deps
      {:mock, "~> 0.3.0", only: :test},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:credo_sonarqube, "~> 0.1.3", only: [:dev, :test]},
      {:sobelow, "~> 0.8", only: :dev},
      {:excoveralls, "~> 0.10", only: :test},
      {:ex_unit_sonarqube, "~> 0.1", only: :test},
      {:benchee, "~> 1.1", only: [:dev, :benchee]},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end

  defp aliases do
    [test: "test --no-start"]
  end

  defp elixirc_paths(:test), do: ["lib", "test"]
  defp elixirc_paths(_), do: ["lib"]

  defp description() do
    "This package provides an elixir connector to the API exposed by ChannelSender"
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["gabheadz", "juancgalvis"],
      licenses: ["MIT"],
      links: %{
        "GitHub" =>
          "https://github.com/bancolombia/async-dataflow/tree/master/clients/backend-client-elixir"
      }
    ]
  end
end
