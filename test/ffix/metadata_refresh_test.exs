defmodule FFix.MetadataRefreshTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Ffix.Refresh.Metadata

  @shell System.find_executable("sh")
  @selection [
    encoder: ~w(libx264 libx265 h264_nvenc aac libopus mpeg4 pcm_s16le ffv1 png),
    decoder: ~w(h264 hevc aac ac3 mpeg4 rawvideo pcm_s16le),
    muxer: ~w(mp4 mov matroska webm hls mpegts segment tee null image2),
    demuxer: ~w(mov matroska rawvideo s16le lavfi mp3 image2)
  ]

  setup do
    directory = Path.join(System.tmp_dir!(), "ffix-refresh-#{System.unique_integer([:positive])}")
    File.mkdir_p!(directory)
    shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(shell)
      File.rm_rf!(directory)
    end)

    executable = fake_ffmpeg(directory)
    %{directory: directory, executable: executable}
  end

  test "refresh captures all filters deterministically with one catalog query per kind",
       context do
    set_filters(context, ["vendor", "null"])
    path = Path.join(context.directory, "priv/ffmpeg/metadata.exs")

    File.cd!(context.directory, fn ->
      Metadata.run(["--ffmpeg", context.executable])
      first = File.read!(path)
      {metadata, []} = Code.eval_file(path)
      assert length(metadata.components) == 33
      assert Enum.map(metadata.filters, & &1.registration.names) == [["null"], ["vendor"]]
      assert Enum.all?(metadata.filters, &(&1.help.names == &1.registration.names))
      assert metadata.version.executable == context.executable

      canonical =
        metadata
        |> inspect(
          pretty: true,
          limit: :infinity,
          printable_limit: :infinity,
          custom_options: [sort_maps: true]
        )
        |> Code.format_string!()
        |> IO.iodata_to_binary()

      assert first == canonical <> "\n"

      calls = File.read!(Path.join(context.directory, "calls")) |> String.split("\n", trim: true)

      for catalog <- ~w(-encoders -decoders -muxers -demuxers -filters) do
        assert Enum.count(calls, &(&1 == catalog)) == 1
      end

      assert Enum.count(calls, &(&1 == "filter=null")) == 1
      assert Enum.count(calls, &(&1 == "filter=vendor")) == 1

      Metadata.run(["--ffmpeg", context.executable])
      assert File.read!(path) == first

      set_filters(context, ["vendor", "null", "added"])
      Metadata.run(["--ffmpeg", context.executable])
      {updated, []} = Code.eval_file(path)

      assert Enum.map(updated.filters, & &1.registration.names) == [
               ["added"],
               ["null"],
               ["vendor"]
             ]

      assert Path.wildcard(path <> ".*.tmp") == []
    end)
  end

  test "failures leave the prior snapshot unchanged", context do
    set_filters(context, ["null", "vendor"])
    path = Path.join(context.directory, "priv/ffmpeg/metadata.exs")

    File.cd!(context.directory, fn ->
      Metadata.run(["--ffmpeg", context.executable])
      original = File.read!(path)

      for {mode, message} <- [
            {"failure", ~r/cannot capture filter vendor/},
            {"mismatch", ~r/help identity does not match/},
            {"malformed", ~r/cannot capture filter vendor/},
            {"missing_pads", ~r/pad|Inputs|outputs|inputs/i}
          ] do
        File.write!(Path.join(context.directory, "mode"), mode)

        assert_raise error_type(mode), message, fn ->
          Metadata.run(["--ffmpeg", context.executable])
        end

        assert File.read!(path) == original
        assert Path.wildcard(path <> ".*.tmp") == []
      end

      File.rm!(Path.join(context.directory, "mode"))
      set_filters(context, ["null", "vendor", "filter"])

      assert_raise ArgumentError, ~r/helper name conflicts/, fn ->
        Metadata.run(["--ffmpeg", context.executable])
      end

      assert File.read!(path) == original
      set_filters(context, ["null"])

      assert_raise Mix.Error, "FFmpeg build is missing recorded filters: vendor", fn ->
        Metadata.run(["--ffmpeg", context.executable])
      end

      assert File.read!(path) == original
    end)
  end

  defp error_type("missing_pads"), do: ArgumentError
  defp error_type(_mode), do: Mix.Error

  defp set_filters(context, names) do
    rows = Enum.map_join(names, "", &" ... #{&1} V->V Fixture\n")
    File.write!(Path.join(context.directory, "filters"), "Filters:\n" <> rows)
  end

  defp fake_ffmpeg(directory) do
    for {kind, names} <- @selection do
      {heading, flags} =
        case kind do
          :encoder -> {"Encoders:", "V....."}
          :decoder -> {"Decoders:", "V....."}
          :muxer -> {"Formats:", " E"}
          :demuxer -> {"Formats:", "D "}
        end

      rows = Enum.map_join(names, "", &" #{flags} #{&1} Fixture\n")
      File.write!(Path.join(directory, "#{kind}s"), heading <> "\n ------\n" <> rows)
    end

    path = Path.join(directory, "ffmpeg fixture")

    File.write!(
      path,
      "#!#{@shell}\n" <>
        """
        [ "$LC_ALL" = C ] || exit 9
        printf '%s\\n' "$4" "$5" >> '#{directory}/calls'
        case "$4" in
          -version) printf 'ffmpeg version fixture Copyright\\n';;
          -encoders|-decoders|-muxers|-demuxers|-filters)
            name="${4#-}"
            cat '#{directory}/'"$name";;
          -h)
            case "$5" in
              full) printf 'AVCodecContext AVOptions:\\n';;
              encoder=*) printf 'Encoder %s [Fixture]:\\n' "${5#encoder=}";;
              decoder=*) printf 'Decoder %s [Fixture]:\\n' "${5#decoder=}";;
              muxer=*) printf 'Muxer %s [Fixture]:\\n' "${5#muxer=}";;
              demuxer=*) printf 'Demuxer %s [Fixture]:\\n' "${5#demuxer=}";;
              filter=*)
                name="${5#filter=}"
                mode=''
                if [ -f '#{directory}/mode' ]; then mode="$(cat '#{directory}/mode')"; fi
                if [ "$name" = vendor ]; then
                  case "$mode" in
                    failure) printf 'capture failed\\n' >&2; exit 3;;
                    mismatch) name=other;;
                    malformed) printf 'invalid help\\n'; exit 0;;
                    missing_pads) printf 'Filter vendor\\n  Fixture\\n'; exit 0;;
                  esac
                fi
                printf 'Filter %s\\n  Fixture\\n    Inputs:\\n       #0: default (video)\\n    Outputs:\\n       #0: default (video)\\n' "$name";;
              *) exit 4;;
            esac;;
          *) exit 5;;
        esac
        """
    )

    File.chmod!(path, 0o700)
    path
  end
end
