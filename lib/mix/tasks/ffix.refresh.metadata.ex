defmodule Mix.Tasks.Ffix.Refresh.Metadata do
  use Mix.Task

  @shortdoc "Refreshes recorded FFmpeg codec, format, and filter metadata"
  @moduledoc """
  Update the bundled FFmpeg option reference and generated helper catalog.

  This is a maintenance task for FFix's recorded reference. Running application
  commands with a different FFmpeg executable normally needs no refresh.

      mix ffix.refresh.metadata --ffmpeg /usr/bin/ffmpeg

  The task captures selected codecs and formats, every registered filter, shared
  options, and build information in `priv/ffmpeg/metadata.exs`. Compilation then
  regenerates helper functions, docs, and typespecs from that reference.

  ## Maintaining the reference

  - Use the same FFmpeg build to reproduce a capture.
  - Review reported filter signature changes and the resulting helper API.
  - Missing previously recorded filters cause a failure. Intentional removals
    require updating the existing reference first.
  - Capture and validation finish before replacing the file, so failures leave
    the recorded reference intact.

  Private, child, and framesync option sections remain separate in the capture.
  Filter helpers expose primary and framesync options; codec/format helpers also
  expose applicable shared options. For querying a build without updating the
  reference, use `FFix.Discovery`.
  """

  alias FFix.Discovery
  alias FFix.Discovery.Exec
  alias FFix.Discovery.Parser
  alias FFix.Helpers

  @metadata_path "priv/ffmpeg/metadata.exs"
  @selection [
    encoder: ~w(libx264 libx265 h264_nvenc aac libopus mpeg4 pcm_s16le ffv1 png),
    decoder: ~w(h264 hevc aac ac3 mpeg4 rawvideo pcm_s16le),
    muxer: ~w(mp4 mov matroska webm hls mpegts segment tee null image2),
    demuxer: ~w(mov matroska rawvideo s16le lavfi mp3 image2)
  ]

  @impl Mix.Task
  def run(arguments) do
    {options, rest, invalid} = OptionParser.parse(arguments, strict: [ffmpeg: :string])

    if rest != [] or invalid != [] do
      Mix.raise("use mix ffix.refresh.metadata [--ffmpeg executable]")
    end

    previous = previous_metadata()
    Mix.Task.run("app.start")
    metadata = capture(options, previous)

    text =
      inspect(metadata,
        pretty: true,
        limit: :infinity,
        printable_limit: :infinity,
        custom_options: [sort_maps: true]
      )

    formatted = text |> Code.format_string!() |> IO.iodata_to_binary()
    write_metadata!(formatted <> "\n")
    Mix.shell().info("Updated #{@metadata_path}")
  end

  defp previous_metadata do
    if File.exists?(@metadata_path) do
      {metadata, []} = Code.eval_file(@metadata_path)
      metadata
    else
      %{}
    end
  end

  defp capture(options, previous) do
    version = discovered!(Discovery.version(options))
    options = Keyword.put(options, :ffmpeg, version.executable)
    shared = discovered!(Discovery.shared(options))

    components =
      Enum.flat_map(@selection, fn {kind, names} ->
        registrations = discovered!(Discovery.list(kind, options))

        Enum.map(names, fn name ->
          registration = Enum.find(registrations, &(name in &1.names))

          if registration == nil do
            Mix.raise("selected #{kind} #{name} is not registered in this FFmpeg build")
          end

          help = capture_help!(kind, name, options)
          Map.put(help, :media_type, Map.get(registration, :media_type))
        end)
      end)

    registrations = discovered!(Discovery.list(:filter, options))
    validate_filter_coverage!(previous, registrations)

    filters =
      registrations
      |> Enum.sort_by(& &1.names)
      |> Enum.map(fn registration ->
        name = hd(registration.names)
        %{registration: registration, help: capture_help!(:filter, name, options)}
      end)

    metadata = %{version: version, shared: shared, components: components, filters: filters}

    Enum.each([:filter, :encoder, :decoder, :muxer, :demuxer], fn kind ->
      Helpers.definitions(metadata, kind)
    end)

    report_signature_changes(previous, filters)
    metadata
  end

  defp capture_help!(kind, name, options) do
    Mix.shell().info("Capturing #{kind} #{name}")

    result =
      with {:ok, capture} <- Exec.run(["-h", "#{kind}=#{name}"], options),
           {:ok, help} <- Parser.help(kind, capture.output) do
        {:ok, help}
      end

    case result do
      {:ok, help} ->
        unless help.kind == kind and name in help.names do
          Mix.raise("cannot capture #{kind} #{name}: help identity does not match")
        end

        help

      {:error, error} ->
        Mix.raise("cannot capture #{kind} #{name}: #{Exception.message(error)}")
    end
  end

  defp validate_filter_coverage!(previous, registrations) do
    previous_names = previous |> Map.get(:filters, []) |> Enum.flat_map(& &1.registration.names)
    current_names = Enum.flat_map(registrations, & &1.names)
    missing = Enum.sort(previous_names -- current_names)

    if missing != [] do
      Mix.raise("FFmpeg build is missing recorded filters: #{Enum.join(missing, ", ")}")
    end
  end

  defp report_signature_changes(previous, filters) do
    signatures = Map.new(Map.get(previous, :filters, []), &signature/1)

    Enum.each(filters, fn entry ->
      {name, current} = signature(entry)

      case Map.fetch(signatures, name) do
        {:ok, previous} when previous != current ->
          Mix.shell().info("Filter #{name} signature changed: #{previous} -> #{current}")

        _unchanged_or_new ->
          :ok
      end
    end)
  end

  defp signature(%{registration: registration}) do
    {hd(registration.names), "#{registration.inputs}->#{registration.outputs}"}
  end

  defp write_metadata!(text) do
    File.mkdir_p!(Path.dirname(@metadata_path))
    temporary = "#{@metadata_path}.#{System.pid()}.#{System.unique_integer([:positive])}.tmp"

    try do
      File.write!(temporary, text, [:exclusive])
      File.rename!(temporary, @metadata_path)
    after
      File.rm(temporary)
    end
  end

  defp discovered!(result) do
    case result do
      {:ok, value} -> value
      {:error, error} -> Mix.raise(Exception.message(error))
    end
  end
end
