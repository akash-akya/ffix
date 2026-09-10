defmodule FFix.Discovery do
  @moduledoc """
  Explicit discovery of the capabilities of an installed FFmpeg build.

  Discovery is separate from command construction and the filter DSL. Nothing
  is scanned at compile time or cached globally. `list/2` fetches a catalog;
  `help/3` checks that registry and fetches just one implementation's help.

      {:ok, encoders} = FFix.Discovery.list(:encoder)
      {:ok, details} = FFix.Discovery.help(:encoder, "libx264")
      {:ok, formats} = FFix.Discovery.list(:pixel_format)

  Component kinds: `:encoder`, `:decoder`, `:codec`, `:muxer`, `:demuxer`,
  `:format`, `:device`, `:filter`, `:bitstream_filter`, `:protocol`.

  Supporting catalogs: `:pixel_format`, `:sample_format`, `:channel`,
  `:channel_layout`, `:hardware_acceleration`, `:disposition`, `:color`.

  Devices are input/output format backends, not physical device inventories.
  Inspect their help with `:demuxer` or `:muxer`. Names are scoped by kind;
  for example, the MOV demuxer's aliases are not aliases of the MP4 muxer.
  Hardware registration does not establish runtime availability.

  Options for all calls:

    * `:ffmpeg` — executable path or name; defaults to `FFMPEG_BIN` or `ffmpeg`
    * `:timeout` — per-command timeout in milliseconds (default: 10_000)
    * `:max_output` — maximum captured bytes per command (default: 8_388_608)

  See `FFix.Discovery.Parser` for the metadata representation and pure parsing.
  Store the result of `version/1` alongside metadata when retaining a snapshot.
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

  @type option :: {:ffmpeg, String.t()} | {:timeout, pos_integer()} | {:max_output, pos_integer()}
  @type result(value) :: {:ok, value} | {:error, Error.t()}

  @doc "Returns the supported catalog kinds without running FFmpeg."
  @spec kinds() :: [atom()]
  def kinds, do: Keyword.keys(@catalogs)

  @doc "Lists registrations or vocabulary entries, preserving aliases and declaration order."
  @spec list(atom(), [option()]) :: result([map()])
  def list(kind, options \\ []) do
    command = Keyword.fetch!(@catalogs, kind)
    query(["-" <> command], &Parser.list(kind, &1), options)
  end

  @doc """
  Fetches details for a registered implementation or format alias.

  `:not_found` means the name is not registered for this kind.
  `:help_unavailable` means it is registered but FFmpeg does not expose help.
  Successful help with `option_sections: []` is valid and distinct from both.
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

  @doc "Fetches shared option sections once, without merging them into private options."
  @spec shared([option()]) :: result([map()])
  def shared(options \\ []), do: query(["-h", "full"], &Parser.shared/1, options)

  @doc "Returns version/build provenance, including the resolved executable path."
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
