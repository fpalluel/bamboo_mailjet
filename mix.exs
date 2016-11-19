defmodule BambooMailjet.Mixfile do
  use Mix.Project

  def project do
    [app: :bamboo_mailjet,
     version: "0.0.1",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def package do
    [
      maintainers: ["moxide"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/moxide/bamboo_mailjet"}
    ]
  end

  def application do
    [applications: [:logger, :bamboo]]
  end

  defp deps do
    [
      {:bamboo, "~> 0.7.0"},
      {:credo, "~> 0.5", only: [:dev, :test]},
      {:cowboy, "~> 1.0", only: [:test, :dev]},
      {:ex_doc, "~> 0.14", only: :docs},
      {:inch_ex, ">= 0.0.0", only: :docs}
    ]
  end
end
