defmodule GeoSQL.Mixfile do
  use Mix.Project

  @source_url "https://github.com/aseigo/geo_sql"
  @version "0.1.0"

  def project do
    [
      app: :geo_sql,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      name: "GeoSQL",
      deps: deps(),
      package: package(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:geometry, github: "aseigo/geometry", branch: "refactor/coordinates-naming"},
      {:postgrex, ">= 0.0.0"},
      {:ecto, "~> 3.13.0"},
      {:ecto_sql, "~> 3.0"},
      {:exqlite, "~> 0.32", override: true},
      {:ecto_sqlite3, "~> 0.21"},
      {:jason, "~> 1.0"},

      # dev
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},

      # testing
      {:mix_test_watch, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      description: "GIS functions for Ecto.",
      files: ["lib", "mix.exs", "README.md", "CHANGELOG.md"],
      maintainers: ["Aaron Seigoh"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      extras: ["CHANGELOG.md", "README.md"],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"],
      groups_for_modules: [
        Standard: [~r/GeoSQL.MM[23].*/],
        "Non-Standard": [~r/GeoSQL.Common.*/],
        PostGIS: [~r/GeoSQL.PostGIS.*/],
        Spatialite: [~r/GeoSQL.SpatialLite.*/]
      ]
    ]
  end

  defp aliases do
    [
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test", "ecto.drop --quiet"]
    ]
  end
end
