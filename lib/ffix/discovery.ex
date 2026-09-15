defmodule FFix.Discovery do
  @moduledoc """
  Inspect the codecs, formats, and filters available in an FFmpeg installation.

  Use discovery to check a deployment's capabilities or build an option picker.
  Each query runs the selected FFmpeg executable and returns `{:ok, metadata}`
  or `{:error, error}`.

      alias FFix.Discovery
      {:ok, encoders} = Discovery.list(:encoder)
      Enum.any?(encoders, fn encoder -> "libx264" in encoder.names end)

      {:ok, details} = Discovery.help(:encoder, "libx264")
      Enum.flat_map(details.option_sections, fn section -> section.options end)

  `list/2` returns a catalog. `help/3` retrieves options and properties for one
  component. `version/1` identifies the build; store it alongside results when
  saving a capability snapshot. Use `FFix.Discovery.Parser` to parse saved
  FFmpeg help text yourself.

  > #### Registration and usability {: .info}
  > A listed hardware encoder may still need a compatible device and driver.
  > Test the intended command on the target machine before relying on it.

  Discovery describes the executable. To inspect tracks inside a media file,
  use [ffprobe](https://ffmpeg.org/ffprobe.html).

  ## Query options

  All query functions accept:

  - `:ffmpeg` — executable path/name; defaults to `FFMPEG_BIN`, then `ffmpeg` on `PATH`.
  - `:timeout` — non-negative milliseconds or `:infinity`; defaults to `10_000`.
  - `:max_output` — non-negative capture limit in bytes; defaults to `8_388_608`.

  A `help/3` query first checks the catalog, then requests help. Limits apply to
  each process. See `FFix.Discovery.Error` for failures and captured diagnostics.
  """

  alias FFix.Discovery.Error
  alias FFix.Discovery.Exec
  alias FFix.Discovery.Parser

  @catalogs [
    encoder: "encoders",
    decoder: "decoders",
    codec: "codecs",
    muxer: "muxers",
    demuxer: "demuxers",
    format: "formats",
    device: "devices",
    filter: "filters",
    bitstream_filter: "bsfs",
    protocol: "protocols",
    pixel_format: "pix_fmts",
    sample_format: "sample_fmts",
    channel: "layouts",
    channel_layout: "layouts",
    hardware_acceleration: "hwaccels",
    disposition: "dispositions",
    color: "colors"
  ]
  @help_topics [
    encoder: "encoder",
    decoder: "decoder",
    muxer: "muxer",
    demuxer: "demuxer",
    filter: "filter",
    bitstream_filter: "bsf",
    protocol: "protocol"
  ]

  @type option ::
          {:ffmpeg, String.t()} | {:timeout, timeout()} | {:max_output, non_neg_integer()}
  @type result(value) :: {:ok, value} | {:error, Error.t()}

  @doc "Returns the catalog kinds accepted by `list/2`. This is the list of query types supported by FFix."
  @spec kinds() :: [atom()]
  def kinds, do: Keyword.keys(@catalogs)

  @doc """
  Lists the entries in an FFmpeg capability catalog.

      FFix.Discovery.list(:filter)
      FFix.Discovery.list(:muxer, ffmpeg: "/usr/local/bin/ffmpeg")

  Component catalogs: `:encoder`, `:decoder`, `:codec`, `:muxer`, `:demuxer`,
  `:format`, `:device`, `:filter`, `:bitstream_filter`, and `:protocol`.
  Other catalogs: `:pixel_format`, `:sample_format`, `:channel`, `:channel_layout`,
  `:hardware_acceleration`, `:disposition`, and `:color`.

  Entries contain a `names` list, retaining aliases, plus the catalog's properties.
  Names are scoped by kind: input-format aliases need not be output-format aliases.
  `:device` lists supported device backends rather than connected physical devices.
  """
  @spec list(atom(), [option()]) :: result([map()])
  def list(kind, options \\ []) do
    command = Keyword.fetch!(@catalogs, kind)
    query(["-" <> command], &Parser.list(kind, &1), options)
  end

  @doc """
  Fetches options and properties for a registered component or format alias.

      FFix.Discovery.help(:muxer, "mp4")

  Supported kinds are `:encoder`, `:decoder`, `:muxer`, `:demuxer`, `:filter`,
  `:bitstream_filter`, and `:protocol`. Inspect a device backend through its
  `:demuxer` or `:muxer` entry.

  Help contains ordered `option_sections` and `properties`; see
  `FFix.Discovery.Parser` for their representation. A component may have an empty
  option list. Errors distinguish an absent registration (`:not_found`) from
  a registration whose help is unavailable (`:help_unavailable`).
  """
  @spec help(atom(), String.t(), [option()]) :: result(map())
  def help(kind, name, options \\ []) do
    topic = Keyword.fetch!(@help_topics, kind)

    with {:ok, entries} <- list(kind, options),
         {:ok, entry} <- find_entry(entries, kind, name),
         {:ok, details} <- query(["-h", topic <> "=" <> name], &Parser.help(kind, &1), options) do
      identify(details, entry, name)
    end
  end

  @doc """
  Fetches general codec, format, and I/O options from FFmpeg's full help.

  Returns separate sections for AVCodecContext, AVFormatContext, AVIOContext,
  and URLContext. Keep section names when displaying options: the same option
  name may have different meanings in different sections.
  """
  @spec shared([option()]) :: result([map()])
  def shared(options \\ []), do: query(["-h", "full"], &Parser.shared/1, options)

  @doc "Returns the FFmpeg version, build configuration, library versions, original text, and resolved executable path."
  @spec version([option()]) :: result(map())
  def version(options \\ []) do
    with {:ok, capture} <- Exec.run(["-version"], options),
         {:ok, version} <- parsed(Parser.version(capture.output), capture) do
      {:ok, Map.put(version, :executable, hd(capture.argv))}
    end
  end

  defp query(arguments, parser, options) do
    with {:ok, capture} <- Exec.run(arguments, options) do
      parsed(parser.(capture.output), capture)
    end
  end

  defp parsed(result, capture) do
    case result do
      {:ok, metadata} ->
        {:ok, metadata}

      {:error, error} ->
        {:error, %{error | argv: capture.argv, output: capture.output}}
    end
  end

  defp find_entry(entries, kind, name) do
    case Enum.find(entries, &(name in &1.names)) do
      nil ->
        {:error,
         %Error{reason: :not_found, message: "#{kind} #{inspect(name)} is not registered"}}

      entry ->
        {:ok, entry}
    end
  end

  defp identify(details, entry, name) do
    case details.kind do
      :protocol -> {:ok, %{details | names: entry.names}}
      _other -> validate_identity(details, name)
    end
  end

  defp validate_identity(details, name) do
    if name in details.names do
      {:ok, details}
    else
      {:error,
       %Error{reason: :invalid_output, message: "help identity does not match #{inspect(name)}"}}
    end
  end
end
