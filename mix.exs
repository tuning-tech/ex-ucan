defmodule ExUcan.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_ucan,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_coverage: [
        summary: [
          threshold: 80
        ],
        ignore_modules: [
          Ucan.Core.Structs.Ucan,
          Ucan.Core.Structs.UcanHeader,
          Ucan.Core.Structs.UcanPayload
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :public_key]
    ]
  end

  def cli() do
    [preferred_envs: [sanity: :test]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:b58, "~> 1.0.2"}
    ]
  end

  defp aliases() do
    [
      sanity: ["test", "format", "credo --strict"]
    ]
  end

end
