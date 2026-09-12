defmodule Mix.Tasks.Ffix.Ffmpeg.Fetch do
  use Mix.Task

  @shortdoc "Download a checksum-pinned static FFmpeg build"
  @moduledoc """
  Download a pinned static FFmpeg build for development.

      mix ffix.ffmpeg.fetch --variant gpl

  Archives come from [BtbN FFmpeg builds](https://github.com/BtbN/FFmpeg-Builds).
  The task checks the archive's SHA-256 against `priv/ffmpeg/checksums.exs`, then
  extracts it under `.ffmpeg/<archive-name>/` and prints the executable paths.
  Select the downloaded binary with `FFMPEG_BIN` or `FFix.run/2`'s `ffmpeg:` option.

  ## Options

  - `--variant gpl|lgpl` — required. GPL builds include encoders such as libx264
    and libx265; LGPL builds omit them. Review the build's licenses before redistribution.
  - `--branch VERSION` — defaults to `9.0`; the branch must have recorded checksums.

  Windows and glibc Linux builds are supported on x86_64 and ARM64. Linux requires
  glibc 2.28+, kernel 4.18+, and `tar` with xz support. For macOS, use an installation
  method listed on [FFmpeg's download page](https://ffmpeg.org/download.html).

  > #### Keep builds explicit {: .info}
  > Downloading leaves your environment and FFix's helper reference unchanged.
  > Choose the executable explicitly when testing a different FFmpeg build.

  An existing destination is left untouched; remove it yourself before fetching
  the same archive again. BtbN archives may expire, and release-branch builds may
  include commits after a point release. To record another dated build, see
  `Mix.Tasks.Ffix.Ffmpeg.Checksum`.
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
