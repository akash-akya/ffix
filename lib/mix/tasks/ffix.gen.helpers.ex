defmodule Mix.Tasks.Ffix.Gen.Helpers do
  use Mix.Task

  @shortdoc "Regenerates codec/format shortcuts from recorded FFmpeg metadata"
  @moduledoc """
  Regenerates the named encoder, decoder, muxer, and demuxer helpers.

      mix ffix.gen.helpers
      mix ffix.gen.helpers --check
      mix ffix.gen.helpers --refresh --ffmpeg /usr/bin/ffmpeg

  Normal generation reads `priv/ffmpeg/helpers.exs` without querying FFmpeg.
  `--refresh` explicitly captures the selected registrations and shared contexts
  from a build, recording version provenance. It requires all selected helpers
  to be registered. Edit the selection in this task when extending the baseline.

  Generated functions are ordinary checked-in Elixir code between markers in
  the four public modules. Generic `named` functions support other registrations.
  The pre-existing filter helpers still have their own compile-time discovery;
  this task does not change that behavior.
  """

  alias FFix.Discovery
  alias FFix.Helpers.Generator

  @snapshot "priv/ffmpeg/helpers.exs"
  @selection [
    encoder: ~w(libx264 libx265 h264_nvenc aac libopus mpeg4 pcm_s16le ffv1 png),
    decoder: ~w(h264 hevc aac ac3 mpeg4 rawvideo pcm_s16le),
    muxer: ~w(mp4 mov matroska webm hls mpegts segment tee null image2),
    demuxer: ~w(mov matroska rawvideo s16le lavfi mp3 image2)
  ]

  @impl Mix.Task
  def run(arguments) do
    {options, rest, invalid} =
      OptionParser.parse(arguments, strict: [refresh: :boolean, check: :boolean, ffmpeg: :string])

    refresh? = Keyword.get(options, :refresh, false)
    check? = Keyword.get(options, :check, false)

    if rest != [] or invalid != [] or (refresh? and check?) do
      Mix.raise("use --check or --refresh [--ffmpeg executable]")
    end

    if options[:ffmpeg] && not refresh? do
      Mix.raise("--ffmpeg requires --refresh")
    end

    Mix.Task.run("compile")

    snapshot =
      case options[:refresh] do
        true ->
          capture = capture(Keyword.take(options, [:ffmpeg]))
          File.mkdir_p!(Path.dirname(@snapshot))
          text = inspect(capture, pretty: true, limit: :infinity, printable_limit: :infinity)
          formatted = text |> Code.format_string!() |> IO.iodata_to_binary()
          File.write!(@snapshot, formatted <> "\n")
          capture

        _other ->
          {capture, []} = Code.eval_file(@snapshot)
          capture
      end

    Enum.each(@selection, fn {kind, _names} ->
      path = "lib/ffix/#{kind}.ex"
      source = File.read!(path)
      generated = Generator.update(source, snapshot, kind)

      case options[:check] do
        true ->
          if source != generated do
            Mix.raise("generated helpers are stale: #{path}")
          end

        _other ->
          File.write!(path, generated)
          Mix.shell().info("Generated #{path}")
      end
    end)
  end

  defp capture(options) do
    Mix.Task.run("app.start")
    version = discovered!(Discovery.version(options))
    shared = discovered!(Discovery.shared(options))

    components =
      Enum.flat_map(@selection, fn {kind, names} ->
        registrations = discovered!(Discovery.list(kind, options))

        Enum.map(names, fn name ->
          Mix.shell().info("Capturing #{kind} #{name}")

          registration = Enum.find(registrations, &(name in &1.names))

          if registration == nil do
            Mix.raise("selected #{kind} #{name} is not registered in this FFmpeg build")
          end

          case Discovery.help(kind, name, options) do
            {:ok, help} ->
              Map.put(help, :media_type, Map.get(registration, :media_type))

            {:error, error} ->
              Mix.raise("cannot capture #{kind} #{name}: #{Exception.message(error)}")
          end
        end)
      end)

    %{version: version, shared: shared, components: components}
  end

  defp discovered!(result) do
    case result do
      {:ok, value} -> value
      {:error, error} -> Mix.raise(Exception.message(error))
    end
  end
end
