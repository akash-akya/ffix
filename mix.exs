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
      extra_applications: [:logger, :inets, :ssl]
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
    "Build and run FFmpeg commands for encoding, filtering, and packaging media in Elixir"
  end

  defp package do
    [
      maintainers: ["Akash Hiremath"],
      licenses: ["MIT"],
      files: ~w(lib priv livebooks/intro.livemd mix.exs README.md LICENSE),
      links: %{
        GitHub: @scm_url,
        ffmpeg: "https://ffmpeg.org"
      }
    ]
  end

  defp docs do
    [
      main: "FFix",
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        {"livebooks/intro.livemd", [title: "Intro Livebook"]},
        "LICENSE"
      ],
      groups_for_modules: [
        "Building commands": [
          FFix,
          FFix.Command.Input,
          FFix.Command.Output,
          FFix.Encoder,
          FFix.Muxer,
          FFix.Demuxer,
          FFix.Decoder,
          FFix.Command.Mapping,
          FFix.Selection,
          FFix.Command
        ],
        "Filters and graphs": [
          FFix.Filter,
          FFix.Graph,
          FFix.Graph.StreamRef,
          FFix.Graph.Terminal,
          FFix.Graph.Export
        ],
        Execution: [
          FFix.Runner,
          FFix.Runner.Result,
          FFix.Runner.Progress,
          FFix.Runner.Log,
          FFix.Runner.Error
        ],
        Discovery: [
          FFix.Discovery,
          FFix.Discovery.Parser,
          FFix.Discovery.Error
        ]
      ],
      nest_modules_by_prefix: [
        FFix.Command,
        FFix.Discovery,
        FFix.Graph,
        FFix.Runner
      ]
    ]
  end
end
