defmodule BambooMailjet.Mixfile do
  use Mix.Project

  def project do
    [
      app: :bamboo_mailjet,
      version: "0.1.0",
      elixir: "~> 1.3",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: "A Mailjet adapter for Bamboo",
      package: package(),
      deps: deps()
    ]
  end

  defp package do
    [
      maintainers: ["moxide"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/moxide/bamboo_mailjet"}
    ]
  end

  def application do
    [
      applications: [:logger, :bamboo]
    ]
  end

  defp deps do
    [
      {:bamboo, "~> 1.2"},
      {:cowboy, "~> 2.6.1", only: [:test, :dev]},
      {:plug_cowboy, "~> 2.0", only: [:test, :dev]},
      {:credo, "~> 1.0.4", only: [:dev, :test]},
      {:poison, "~> 4.0", only: [:dev, :test]},
      {:ex_doc, "~> 0.19", only: :dev},
      {:inch_ex, "~> 2.0.0", only: :dev}
    ]
  end
end
