defmodule Mix.Tasks.Ffix.Ffmpeg.Checksum do
  use Mix.Task

  @shortdoc "Record checksums for a dated BtbN FFmpeg build"
  @moduledoc """
  Records static GPL/LGPL archive checksums without downloading the binaries.

      mix ffix.ffmpeg.checksum --release autobuild-2026-09-07-15-39 [--branch 9.0]

  Updates `priv/ffmpeg/checksums.exs`, preserving other branches.
  """

  alias Mix.FFix.FFmpegDownload, as: Download

  @impl Mix.Task
  def run(arguments) do
    {options, rest, invalid} =
      OptionParser.parse(arguments, strict: [release: :string, branch: :string])

    if rest != [] or invalid != [] do
      Mix.raise("use mix ffix.ffmpeg.checksum --release TAG [--branch 9.0]")
    end

    release = Download.release!(options[:release])
    branch = Download.branch!(Keyword.get(options, :branch, "9.0"))
    url = Download.url(release, "checksums.sha256")
    Mix.shell().info("Downloading #{url}")

    Download.in_temporary_directory(System.tmp_dir!(), fn temporary ->
      path = Path.join(temporary, "checksums.sha256")
      Download.download!(url, path)
      entry = Download.checksum_entry!(File.read!(path), release, branch)
      Download.update_checksums!("priv/ffmpeg/checksums.exs", branch, entry)

      Mix.shell().info(
        "Updated priv/ffmpeg/checksums.exs (#{map_size(entry.files)} archives for #{branch})"
      )
    end)
  end
end
