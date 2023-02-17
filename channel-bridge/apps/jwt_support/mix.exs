defmodule JwtSupport.MixProject do
  use Mix.Project

  def project do
    [
      app: :jwt_support,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      ## == begin aws set of dependencies ==
      {:ex_aws, "~> 2.2"},
      {:ex_aws_sts, "~> 2.2"},
      {:ex_aws_kms, "~> 2.2"},
      {:configparser_ex, "~> 4.0"},
      {:sweet_xml, "~> 0.6"},
      ## == end of aws set of dependencies ==
      {:jose, "~> 1.11.1"},
      ## testing deps
      {:mock, "~> 0.3.0", only: :test},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:credo_sonarqube, "~> 0.1.3", only: [:dev, :test]},
      {:sobelow, "~> 0.8", only: :dev},
      {:excoveralls, "~> 0.10", only: :test},
      {:ex_unit_sonarqube, "~> 0.1", only: :test}
    ]
  end
end
