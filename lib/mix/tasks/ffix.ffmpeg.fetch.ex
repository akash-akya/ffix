defmodule Mix.Tasks.Ffix.Ffmpeg.Fetch do
  use Mix.Task

  @shortdoc "Download a checksum-pinned static FFmpeg build"
  @moduledoc """
  Downloads the recorded build for the current platform. Variant is required.

      mix ffix.ffmpeg.fetch --variant gpl
      mix ffix.ffmpeg.fetch --variant lgpl --branch 8.1

  Branch defaults to 9.0. Extracts under `.ffmpeg/<archive-name>/` without changing
  the environment.
  BtbN supports Windows and glibc Linux; Linux extraction requires tar/xz.
  """

  alias Mix.FFix.FFmpegDownload, as: Download

  @impl Mix.Task
  def run(arguments) do
    {options, rest, invalid} =
      OptionParser.parse(arguments, strict: [variant: :string, branch: :string])

    if rest != [] or invalid != [] do
      Mix.raise("use mix ffix.ffmpeg.fetch --variant gpl|lgpl [--branch 9.0]")
    end

    variant = Download.variant!(options[:variant])
    branch = Download.branch!(Keyword.get(options, :branch, "9.0"))
    checksums = Download.read_checksums!("priv/ffmpeg/checksums.exs")
    asset = Download.asset!(checksums, branch, Download.target!(), variant)
    directory = Path.expand(".ffmpeg")
    Download.available_destination!(Download.destination(asset, directory))
    url = Download.url(asset.release, asset.filename)
    Mix.shell().info("Downloading #{url}")

    Download.in_temporary_directory(directory, fn temporary ->
      archive = Path.join(temporary, asset.filename)
      Download.download!(url, archive)
      destination = Download.install!(archive, asset, directory)

      destination
      |> Path.join("bin/*")
      |> Path.wildcard()
      |> Enum.each(fn path -> Mix.shell().info(path) end)
    end)
  end
end
