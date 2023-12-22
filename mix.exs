defmodule ExUcan.MixProject do
  use Mix.Project

  def project do
    [
      app: :ucan,
      version: "0.10.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      consolidate_protocols: Mix.env() != :test,
      elixirc_paths: elixirc_paths(Mix.env()),
      description: """
        Elixir implementation of UCANs
      """,
      test_coverage: [
        summary: [
          threshold: 80
        ],
        ignore_modules: [
          Ucan.Core.Structs.Ucan,
          Ucan.UcanHeader,
          Ucan.UcanPayload,
          Inspect.Ucan.Keymaterial.Ed25519.Keypair,
          String.Chars.Ucan.WnfsCapLevel,
          String.Chars.Ucan.WnfsScope,
          Ucan.Capability.Resource,
          Ucan.Capability.Resource.As,
          Ucan.Capability.Resource.My,
          Ucan.Capability.Resource.ResourceType,
          Ucan.Capability.Scope.Ucan.ProofSelection,
          Ucan.Capability.Scope.Ucan.WnfsScope,
          Ucan.EmailAction,
          Ucan.EmailAddress,
          Ucan.Utility.Convert.Ucan.WnfsCapLevel,
          Ucan.Utility.Convert.Ucan.WnfsScope,
          Ucan.Utility.PartialOrder.Ucan.ProofAction,
          Ucan.Utility.PartialOrder.Ucan.WnfsCapLevel,
          Ucan.WnfsCapLevel,
          Ucan.WnfsScope,
          Ucan.WnfsSemantics
        ]
      ],
      source_url: "https://github.com/tuning-tech/ex-ucan"
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
      {:b58, "~> 1.0.2"},
      {:excid, git: "https://github.com/madclaws/cid.git"},
      {:ex_ipfs_ipld, "~> 1.0"},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false}
    ]
  end

  defp aliases() do
    [
      sanity: ["test", "format", "credo --strict"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/fixtures"]
  defp elixirc_paths(_), do: ["lib"]
end
