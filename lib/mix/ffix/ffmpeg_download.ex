defmodule Mix.FFix.FFmpegDownload do
  @moduledoc false

  import NimbleParsec

  @base_url "https://github.com/BtbN/FFmpeg-Builds/releases/download"
  @targets ~w(linux64 linuxarm64 win64 winarm64)

  defparsecp(
    :checksum_line,
    ascii_string([?0..?9, ?a..?f, ?A..?F], 64)
    |> ignore(ascii_string([?\s, ?\t], min: 1))
    |> optional(ignore(string("*")))
    |> utf8_string([{:not, ?\s}, {:not, ?\t}], min: 1)
    |> eos()
  )

  def branch!(branch) do
    unless is_binary(branch) and Regex.match?(~r/\A[0-9]+\.[0-9]+\z/, branch) do
      Mix.raise("expected an FFmpeg branch such as 9.0, got: #{inspect(branch)}")
    end

    branch
  end

  def release!(release) do
    unless is_binary(release) and
             Regex.match?(~r/\Aautobuild-[0-9]{4}(?:-[0-9]{2}){4}\z/, release) do
      Mix.raise("--release must be a dated BtbN tag such as autobuild-2026-09-07-15-39")
    end

    release
  end

  def variant!(variant) do
    unless variant in ["gpl", "lgpl"] do
      Mix.raise("--variant is required and must be gpl or lgpl")
    end

    variant
  end

  def target!(os \\ :os.type(), architecture \\ :erlang.system_info(:system_architecture)) do
    architecture = to_string(architecture)
    processor = architecture |> String.split("-") |> hd()

    target =
      case {os, processor} do
        {{:unix, :linux}, "x86_64"} -> "linux64"
        {{:unix, :linux}, "aarch64"} -> "linuxarm64"
        {{:win32, _name}, "x86_64"} -> "win64"
        {{:win32, _name}, "aarch64"} -> "winarm64"
        _other -> nil
      end

    if target == nil or String.contains?(architecture, "musl") do
      Mix.raise("no BtbN static build for #{inspect(os)} / #{architecture}")
    end

    target
  end

  def url(release, filename), do: "#{@base_url}/#{release!(release)}/#{filename}"

  def checksum_entry!(text, release, branch) do
    release!(release)
    branch!(branch)

    files =
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.reduce(%{}, fn line, files ->
        case checksum_line(line) do
          {:ok, [checksum, filename], "", _context, _line, _offset} ->
            if Map.has_key?(files, filename), do: Mix.raise("duplicate checksum: #{filename}")
            Map.put(files, filename, "sha256:" <> String.downcase(checksum))

          _invalid ->
            Mix.raise("invalid SHA-256 checksum row: #{inspect(line)}")
        end
      end)
      |> Map.filter(fn {filename, _checksum} -> asset_kind(filename, branch) != nil end)

    if map_size(files) == 0 do
      Mix.raise("no static GPL/LGPL archives for FFmpeg #{branch} in #{release}")
    end

    kinds = Enum.map(files, fn {filename, _checksum} -> asset_kind(filename, branch) end)

    if length(kinds) != length(Enum.uniq(kinds)) do
      Mix.raise("multiple archives for the same platform and variant in #{release}")
    end

    %{release: release, files: files}
  end

  def read_checksums!(path) do
    case File.read(path) do
      {:ok, text} ->
        case Code.eval_string(text) do
          {%{} = checksums, []} -> checksums
          _invalid -> Mix.raise("expected a checksum map in #{path}")
        end

      {:error, :enoent} ->
        %{}

      {:error, reason} ->
        raise File.Error, reason: reason, action: "read file", path: path
    end
  end

  def update_checksums!(path, branch, entry) do
    checksums = path |> read_checksums!() |> Map.put(branch, entry)

    text =
      checksums
      |> inspect(pretty: true, limit: :infinity, custom_options: [sort_maps: true])
      |> Code.format_string!()
      |> IO.iodata_to_binary()

    File.mkdir_p!(Path.dirname(path))
    temporary = path <> ".#{System.pid()}.#{System.unique_integer([:positive])}.tmp"

    try do
      File.write!(temporary, text <> "\n", [:exclusive])
      File.rename!(temporary, path)
    after
      File.rm(temporary)
    end
  end

  def asset!(checksums, branch, target, variant) do
    branch!(branch)
    variant!(variant)

    entry =
      Map.get(checksums, branch) ||
        Mix.raise("no checksums for FFmpeg #{branch}; run mix ffix.ffmpeg.checksum --release TAG")

    release!(entry.release)

    matches =
      Enum.filter(entry.files, fn {filename, _checksum} ->
        asset_kind(filename, branch) == {target, variant}
      end)

    case matches do
      [{filename, "sha256:" <> checksum}] ->
        unless Regex.match?(~r/\A[0-9a-f]{64}\z/, checksum) do
          Mix.raise("invalid recorded SHA-256 for #{filename}")
        end

        %{release: entry.release, filename: filename, checksum: checksum}

      _other ->
        Mix.raise(
          "expected one recorded static #{target} #{variant} archive for FFmpeg #{branch}"
        )
    end
  end

  def download!(url, path) do
    {:ok, _applications} = Application.ensure_all_started(:inets)
    {:ok, _applications} = Application.ensure_all_started(:ssl)

    http_options = [
      timeout: 300_000,
      connect_timeout: 15_000,
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
      ]
    ]

    # Stream archives to disk rather than retaining hundreds of megabytes in the VM.
    result =
      :httpc.request(:get, {String.to_charlist(url), []}, http_options,
        stream: String.to_charlist(path)
      )

    case result do
      {:ok, :saved_to_file} ->
        :ok

      {:ok, {{_version, status, _reason}, _headers, _body}} ->
        Mix.raise("download failed (HTTP #{status}): #{url}")

      {:error, reason} ->
        Mix.raise("download failed: #{url}: #{inspect(reason)}")
    end
  end

  def in_temporary_directory(parent, callback) do
    directory =
      Path.join(parent, ".ffix-download-#{System.pid()}-#{System.unique_integer([:positive])}")

    File.mkdir_p!(parent)
    File.mkdir!(directory)

    try do
      callback.(directory)
    after
      File.rm_rf!(directory)
    end
  end

  def destination(asset, directory) do
    Path.join(directory, archive_root(asset.filename))
  end

  def available_destination!(destination) do
    if File.exists?(destination) do
      Mix.raise("#{destination} already exists; remove it before downloading again")
    end
  end

  def install!(archive, asset, directory) do
    destination = destination(asset, directory)
    available_destination!(destination)
    verify!(archive, asset.checksum)
    root = archive_root(asset.filename)

    in_temporary_directory(directory, fn temporary ->
      extract!(archive, temporary, root)
      extracted = Path.join(temporary, root)
      suffix = if String.ends_with?(asset.filename, ".zip"), do: ".exe", else: ""

      for name <- ["ffmpeg", "ffprobe"] do
        path = Path.join([extracted, "bin", name <> suffix])
        unless File.regular?(path), do: Mix.raise("archive is missing #{name <> suffix}")
      end

      File.rename!(extracted, destination)
    end)

    destination
  end

  defp asset_kind(filename, branch) do
    pattern =
      ~r/\Affmpeg-[a-zA-Z0-9._-]+-(linux64|linuxarm64|win64|winarm64)-(gpl|lgpl)-#{Regex.escape(branch)}\.(tar\.xz|zip)\z/

    case Regex.run(pattern, filename) do
      [_filename, target, variant, extension] when target in @targets ->
        expected = if String.starts_with?(target, "win"), do: "zip", else: "tar.xz"
        if extension == expected, do: {target, variant}

      _other ->
        nil
    end
  end

  defp archive_root(filename) do
    filename |> String.trim_trailing(".tar.xz") |> String.trim_trailing(".zip")
  end

  defp verify!(archive, expected) do
    digest =
      archive
      |> File.stream!([], 65_536)
      |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)

    if digest != expected do
      Mix.raise("SHA-256 mismatch for #{Path.basename(archive)}; checksum file was not changed")
    end
  end

  defp extract!(archive, temporary, root) do
    if String.ends_with?(archive, ".zip") do
      archive = String.to_charlist(archive)

      entries =
        case :zip.table(archive) do
          {:ok, entries} -> entries
          {:error, reason} -> Mix.raise("cannot read ZIP archive: #{inspect(reason)}")
        end

      names =
        for {:zip_file, name, _info, _comment, _offset, _size} <- entries, do: to_string(name)

      validate_paths!(names, root)

      case :zip.extract(archive, cwd: String.to_charlist(temporary)) do
        {:ok, _files} -> :ok
        {:error, reason} -> Mix.raise("cannot extract archive: #{inspect(reason)}")
      end
    else
      names = tar!(["-tJf", archive]) |> String.split("\n", trim: true)
      validate_paths!(names, root)
      types = tar!(["-tvJf", archive]) |> String.split("\n", trim: true)

      # Links could redirect subsequent archive entries outside the extraction directory.
      unless Enum.all?(types, &String.starts_with?(&1, ["-", "d"])) do
        Mix.raise("archive must contain only regular files and directories")
      end

      tar!(["-xJf", archive, "-C", temporary, "--no-same-owner", "--no-same-permissions"])
    end
  end

  defp validate_paths!(names, root) do
    Enum.each(names, fn name ->
      parts = String.split(name, "/")

      unless hd(parts) == root and ".." not in parts and not String.contains?(name, "\\") do
        Mix.raise("unsafe archive path: #{inspect(name)}")
      end
    end)
  end

  defp tar!(arguments) do
    executable = System.find_executable("tar") || Mix.raise("tar with xz support is required")

    case System.cmd(executable, arguments, stderr_to_stdout: true) do
      {output, 0} -> output
      {output, _status} -> Mix.raise("cannot extract archive: #{String.trim(output)}")
    end
  end
end
