defmodule FFix.MixProject do
  use Mix.Project

  @version "0.1.0"
  @scm_url "https://github.com/akash-akya/ffix"

  def project do
    [
      app: :ffix,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      source_url: @scm_url,
      homepage_url: @scm_url,
      docs: docs()
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
      {:nimble_parsec, "~> 1.4"},
      {:exile, "~> 0.14"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Elixir data model and builder for ffmpeg filtergraphs and commands"
  end

  defp package do
    [
      maintainers: ["Akash Hiremath"],
      licenses: ["MIT"],
      files: ~w(lib mix.exs README.md LICENSE),
      links: %{
        GitHub: @scm_url,
        ffmpeg: "https://ffmpeg.org"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: ["README.md", "LICENSE"]
    ]
  end
end
