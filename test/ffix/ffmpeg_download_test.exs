defmodule FFix.FFmpegDownloadTest do
  use ExUnit.Case, async: false

  alias Mix.FFix.FFmpegDownload, as: Download
  alias Mix.Tasks.Ffix.Ffmpeg.{Checksum, Fetch}

  @release "autobuild-2026-09-07-15-39"
  @checksum String.duplicate("a", 64)

  setup do
    directory =
      Path.join(System.tmp_dir!(), "ffix-download-test-#{System.unique_integer([:positive])}")

    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)
    %{directory: directory}
  end

  test "records both static variants for all available targets, without shared or other branches" do
    selected =
      for target <- ~w(linux64 linuxarm64 win64 winarm64),
          variant <- ~w(gpl lgpl),
          do: filename(target, variant)

    excluded = [
      filename("linux64", "gpl-shared"),
      filename("linux64", "gpl", "8.1"),
      "ffmpeg-N-12345-linux64-gpl.tar.xz"
    ]

    text = Enum.map_join(selected ++ excluded, "\r\n", &"#{String.upcase(@checksum)} *#{&1}")
    entry = Download.checksum_entry!(text, @release, "9.0")
    assert entry.release == @release
    assert Enum.sort(Map.keys(entry.files)) == Enum.sort(selected)
    assert Enum.uniq(Map.values(entry.files)) == ["sha256:" <> @checksum]

    for target <- ~w(linux64 linuxarm64 win64 winarm64), variant <- ~w(gpl lgpl) do
      asset = Download.asset!(%{"9.0" => entry}, "9.0", target, variant)
      assert asset.filename == filename(target, variant)
      assert asset.checksum == @checksum

      assert Download.url(asset.release, asset.filename) ==
               "https://github.com/BtbN/FFmpeg-Builds/releases/download/#{@release}/#{asset.filename}"
    end
  end

  test "invalid and ambiguous checksum records fail explicitly" do
    row = "#{@checksum}  #{filename("linux64", "gpl")}"

    for text <- ["invalid", "#{String.duplicate("a", 63)} filename", row <> "\n" <> row] do
      assert_raise Mix.Error, fn -> Download.checksum_entry!(text, @release, "9.0") end
    end

    assert_raise Mix.Error, ~r/multiple archives/, fn ->
      other = String.replace(row, "n9.0.1-27", "n9.0.1-28")
      Download.checksum_entry!(row <> "\n" <> other, @release, "9.0")
    end

    for text <- [
          "",
          "#{@checksum} ../../escape",
          "#{@checksum} #{filename("linux64", "gpl", "8.1")}"
        ] do
      assert_raise Mix.Error, ~r/no static GPL\/LGPL archives/, fn ->
        Download.checksum_entry!(text, @release, "9.0")
      end
    end
  end

  test "checksum updates are sorted, preserve other branches and never touch helper metadata",
       context do
    path = Path.join(context.directory, "priv/ffmpeg/checksums.exs")
    metadata_path = Path.join(context.directory, "priv/ffmpeg/metadata.exs")

    old = %{
      release: @release,
      files: %{filename("linux64", "gpl", "8.1") => "sha256:" <> @checksum}
    }

    Download.update_checksums!(path, "8.1", old)
    File.write!(metadata_path, "unchanged")
    entry = entry()
    Download.update_checksums!(path, "9.0", entry)
    first = File.read!(path)
    Download.update_checksums!(path, "9.0", entry)
    assert File.read!(path) == first
    assert Download.read_checksums!(path) == %{"8.1" => old, "9.0" => entry}
    assert File.read!(metadata_path) == "unchanged"
    assert Path.wildcard(path <> ".*.tmp") == []

    assert_raise Mix.Error, fn ->
      invalid = Download.checksum_entry!("bad checksum", @release, "9.0")
      Download.update_checksums!(path, "9.0", invalid)
    end

    assert File.read!(path) == first
  end

  test "missing, malformed and corrupt local checksum files are not silently accepted", context do
    path = Path.join(context.directory, "checksums.exs")
    assert Download.read_checksums!(path) == %{}

    assert_raise Mix.Error, ~r/no checksums/, fn ->
      Download.asset!(%{}, "9.0", "linux64", "gpl")
    end

    File.write!(path, "[]")
    assert_raise Mix.Error, ~r/checksum map/, fn -> Download.read_checksums!(path) end

    files = %{filename("linux64", "gpl") => "sha256:invalid"}

    assert_raise Mix.Error, ~r/invalid recorded SHA-256/, fn ->
      Download.asset!(%{"9.0" => %{entry() | files: files}}, "9.0", "linux64", "gpl")
    end

    assert_raise Mix.Error, ~r/expected one recorded/, fn ->
      Download.asset!(%{"9.0" => entry()}, "9.0", "linux64", "lgpl")
    end
  end

  test "platform detection supports BtbN targets and rejects unsupported systems" do
    assert Download.target!({:unix, :linux}, ~c"x86_64-pc-linux-gnu") == "linux64"
    assert Download.target!({:unix, :linux}, ~c"aarch64-unknown-linux-gnu") == "linuxarm64"
    assert Download.target!({:win32, :nt}, ~c"x86_64-pc-win32") == "win64"
    assert Download.target!({:win32, :nt}, ~c"aarch64-pc-win32") == "winarm64"

    for {os, architecture} <- [
          {{:unix, :darwin}, "aarch64-apple-darwin"},
          {{:unix, :linux}, "x86_64-linux-musl"},
          {{:unix, :linux}, "i686-linux-gnu"}
        ] do
      assert_raise Mix.Error, ~r/no BtbN static build/, fn ->
        Download.target!(os, architecture)
      end
    end
  end

  test "Mix tasks require a dated release or an explicit static variant" do
    for arguments <- [
          [],
          ["--release", "latest"],
          ["--release", "../escape"],
          ["--unknown"],
          ["9.0"]
        ] do
      assert_raise Mix.Error, fn -> Checksum.run(arguments) end
    end

    for arguments <- [
          [],
          ["--variant", "gpl-shared"],
          ["--variant", "nonfree"],
          ["--unknown"],
          ["gpl"]
        ] do
      assert_raise Mix.Error, fn -> Fetch.run(arguments) end
    end

    assert_raise Mix.Error, ~r/expected an FFmpeg branch/, fn ->
      Checksum.run(["--release", @release, "--branch", "../9.0"])
    end
  end

  test "fetch defaults to branch 9.0 and does not update missing checksums", context do
    File.cd!(context.directory, fn ->
      assert_raise Mix.Error, ~r/no checksums for FFmpeg 9.0/, fn ->
        Fetch.run(["--variant", "gpl"])
      end

      refute File.exists?("priv/ffmpeg/checksums.exs")
      refute File.exists?(".ffmpeg")
    end)
  end

  test "verified tar and zip archives retain their own directory, binaries, and licenses",
       context do
    for target <- ["linux64", "win64"], variant <- ["gpl", "lgpl"] do
      {archive, asset} = archive!(context.directory, target, variant)
      destination = Download.install!(archive, asset, Path.join(context.directory, ".ffmpeg"))
      root = asset.filename |> String.trim_trailing(".tar.xz") |> String.trim_trailing(".zip")
      assert destination == Path.join([context.directory, ".ffmpeg", root])
      assert File.read!(Path.join(destination, "LICENSE.txt")) == "fixture license"
      suffix = if target == "win64", do: ".exe", else: ""
      assert File.read!(Path.join(destination, "bin/ffmpeg" <> suffix)) == "fixture ffmpeg"
      assert File.read!(Path.join(destination, "bin/ffprobe" <> suffix)) == "fixture ffprobe"
      assert Path.wildcard(Path.join(context.directory, ".ffmpeg/.ffix-download-*")) == []

      assert_raise Mix.Error, ~r/already exists/, fn ->
        Download.install!(archive, asset, Path.join(context.directory, ".ffmpeg"))
      end

      assert File.read!(Path.join(destination, "LICENSE.txt")) == "fixture license"
    end
  end

  test "checksum failure occurs before extraction and temporary downloads are removed", context do
    directory = Path.join(context.directory, ".ffmpeg")

    assert_raise Mix.Error, ~r/SHA-256 mismatch/, fn ->
      Download.in_temporary_directory(directory, fn temporary ->
        archive = Path.join(temporary, filename("win64", "gpl"))
        File.write!(archive, "not an archive")
        asset = %{filename: Path.basename(archive), checksum: @checksum}
        Download.install!(archive, asset, directory)
      end)
    end

    assert File.ls!(directory) == []
  end

  test "corrupt and incomplete archives do not leave an installation", context do
    for content <- ["not a ZIP", :empty] do
      archive = Path.join(context.directory, filename("win64", "gpl"))

      if content == :empty do
        {:ok, _path} = :zip.create(String.to_charlist(archive), [])
      else
        File.write!(archive, content)
      end

      asset = archive_asset(archive)
      destination = Download.destination(asset, context.directory)
      assert_raise Mix.Error, fn -> Download.install!(archive, asset, context.directory) end
      refute File.exists?(destination)
      assert Path.wildcard(Path.join(context.directory, ".ffix-download-*")) == []
    end
  end

  @tag capture_log: true
  test "ZIP paths cannot escape their archive root", context do
    for name <- ["../escape", "/escape", "root/../../escape", "root\\..\\escape"] do
      archive = Path.join(context.directory, filename("win64", "gpl"))
      {:ok, _path} = :zip.create(String.to_charlist(archive), [{String.to_charlist(name), "bad"}])

      assert_raise Mix.Error, ~r/unsafe archive path/, fn ->
        Download.install!(archive, archive_asset(archive), context.directory)
      end
    end

    refute File.exists?(Path.join(context.directory, "escape"))
  end

  test "tar links are rejected before extraction", context do
    {archive, _asset} = archive!(context.directory, "linux64", "gpl")
    root = archive |> Path.basename() |> String.trim_trailing(".tar.xz")
    source = Path.join(context.directory, "source")
    File.ln_s!(context.directory, Path.join([source, root, "link"]))
    {_output, 0} = System.cmd("tar", ["-cJf", archive, "-C", source, root])

    assert_raise Mix.Error, ~r/only regular files and directories/, fn ->
      Download.install!(archive, archive_asset(archive), Path.join(context.directory, ".ffmpeg"))
    end
  end

  test "HTTP downloads stream to disk and unsuccessful responses fail", context do
    body = String.duplicate("archive bytes", 10_000)
    path = Path.join(context.directory, "download")

    serve_once("200 OK", body, fn url ->
      assert Download.download!(url, path) == :ok
      assert File.read!(path) == body
    end)

    serve_once("404 Not Found", "missing", fn url ->
      assert_raise Mix.Error, ~r/HTTP 404/, fn ->
        Download.download!(url, Path.join(context.directory, "missing"))
      end
    end)
  end

  defp serve_once(status, body, callback) do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_address, port}} = :inet.sockname(listener)

    server =
      Task.async(fn ->
        {:ok, socket} = :gen_tcp.accept(listener, 5_000)
        {:ok, _request} = :gen_tcp.recv(socket, 0, 5_000)

        :ok =
          :gen_tcp.send(socket, [
            "HTTP/1.1 #{status}\r\nContent-Length: #{byte_size(body)}\r\nConnection: close\r\n\r\n",
            body
          ])

        :gen_tcp.close(socket)
      end)

    try do
      callback.("http://127.0.0.1:#{port}/archive")
      Task.await(server)
    after
      :gen_tcp.close(listener)
      Task.shutdown(server)
    end
  end

  defp filename(target, variant, branch \\ "9.0") do
    extension = if String.starts_with?(target, "win"), do: "zip", else: "tar.xz"
    "ffmpeg-n#{branch}.1-27-gabcdef-#{target}-#{variant}-#{branch}.#{extension}"
  end

  defp entry do
    %{release: @release, files: %{filename("linux64", "gpl") => "sha256:" <> @checksum}}
  end

  defp archive!(directory, target, variant) do
    filename = filename(target, variant)
    root = filename |> String.trim_trailing(".tar.xz") |> String.trim_trailing(".zip")
    source = Path.join(directory, "source")
    bin = Path.join([source, root, "bin"])
    File.mkdir_p!(bin)
    suffix = if String.starts_with?(target, "win"), do: ".exe", else: ""

    for name <- ["ffmpeg", "ffprobe"] do
      path = Path.join(bin, name <> suffix)
      File.write!(path, "fixture #{name}")
      File.chmod!(path, 0o755)
    end

    File.write!(Path.join([source, root, "LICENSE.txt"]), "fixture license")
    archive = Path.join(directory, filename)

    if suffix == ".exe" do
      {:ok, _path} =
        :zip.create(String.to_charlist(archive), [String.to_charlist(root)],
          cwd: String.to_charlist(source)
        )
    else
      {_output, 0} = System.cmd("tar", ["-cJf", archive, "-C", source, root])
    end

    {archive, archive_asset(archive)}
  end

  defp archive_asset(archive) do
    checksum = :crypto.hash(:sha256, File.read!(archive)) |> Base.encode16(case: :lower)
    %{filename: Path.basename(archive), checksum: checksum}
  end
end
