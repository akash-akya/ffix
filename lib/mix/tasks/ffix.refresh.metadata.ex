defmodule Mix.Tasks.Ffix.Refresh.Metadata do
  use Mix.Task

  @shortdoc "Refreshes recorded FFmpeg codec and format metadata"
  @moduledoc """
  Updates `priv/ffmpeg/metadata.exs` from the selected FFmpeg build.

      mix ffix.refresh.metadata --ffmpeg /usr/bin/ffmpeg

  The build must provide all registrations in this task's selection. Helpers,
  docs, and typespecs update on the next compilation.
  """

  alias FFix.Discovery

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

    Mix.Task.run("app.start")
    metadata = capture(options)
    text = inspect(metadata, pretty: true, limit: :infinity, printable_limit: :infinity)
    formatted = text |> Code.format_string!() |> IO.iodata_to_binary()
    File.mkdir_p!(Path.dirname(@metadata_path))
    File.write!(@metadata_path, formatted <> "\n")
    Mix.shell().info("Updated #{@metadata_path}")
  end

  defp capture(options) do
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
