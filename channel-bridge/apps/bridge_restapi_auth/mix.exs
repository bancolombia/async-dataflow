defmodule BridgeRestapiAuth.MixProject do
  use Mix.Project

  def project do
    [
      app: :bridge_restapi_auth,
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
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:jose, "~> 1.11.1"},
      {:mock, "~> 0.3.8", only: :test}
    ]
  end
end
