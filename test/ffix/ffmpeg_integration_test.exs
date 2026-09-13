defmodule FFix.FFmpegIntegrationTest do
  use ExUnit.Case, async: false
  alias FFix.Command
  alias FFix.Command.{Mapping, Output}
  alias FFix.{Decoder, Demuxer, Encoder, Filter, Graph, Muxer}
  @moduletag :integration
  @ffmpeg System.find_executable("ffmpeg")
  @ffprobe System.find_executable("ffprobe")
  if is_nil(@ffmpeg) or is_nil(@ffprobe) do
    @moduletag skip: "ffmpeg and ffprobe are required for integration tests"
  end

  setup_all do
    fixture_dir =
      Path.join(
        System.tmp_dir!(),
        "ffix-integration-fixtures-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(fixture_dir)
    sample_video = Path.join(fixture_dir, "sample.mp4")
    create_sample_video!(sample_video)
    on_exit(fn -> File.rm_rf!(fixture_dir) end)
    {:ok, sample_video: sample_video}
  end

  setup context do
    tmp_dir =
      Path.join(System.tmp_dir!(), "ffix-integration-#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    {:ok, tmp_dir: tmp_dir, sample_video: context.sample_video}
  end

  test("runs a branching graph and writes the expected stacked frame", %{
    tmp_dir: tmp_dir,
    sample_video: sample_video
  }) do
    src = FFix.input(sample_video)
    scaled = FFix.video(src, 0) |> Filter.scale(w: 96, h: -1)
    [left, right] = Filter.split(scaled, outputs: 2)
    stacked = Filter.hstack([left, Filter.hflip(right)])
    output_pattern = Path.join(tmp_dir, "stacked-%03d.jpg")
    output_file = Path.join(tmp_dir, "stacked-001.jpg")

    command =
      FFix.command(
        [
          FFix.output(FFix.graph(outputs: [stacked: stacked])[:stacked], output_pattern, [
            {"frames:v", 1},
            {"q:v", 3},
            f: :image2,
            an: :flag
          ])
        ],
        global: ffmpeg_globals(),
        inputs: [src]
      )

    run_ffmpeg!(command)
    assert_nonempty_file!(output_file)
    assert {192, 54} == probe_dimensions!(output_file)
  end

  test("runs generic filters with explicit shapes through an encoder and muxer", %{
    tmp_dir: tmp_dir,
    sample_video: sample_video
  }) do
    target = Path.join(tmp_dir, "generic.png")
    source = FFix.input(sample_video)

    command =
      FFix.command(
        source
        |> FFix.video(0)
        |> Filter.filter("scale", [:video], w: 80, h: -2)
        |> Filter.filter("hflip", [:video])
        |> Encoder.png(threads: 1)
        |> Muxer.image2(target, update: true, output_options: ["frames:v": 1]),
        global: ffmpeg_globals()
      )

    run_ffmpeg!(command)
    assert_nonempty_file!(target)
    assert probe_dimensions!(target) == {80, 46}
  end

  test("accepts a parsed round-tripped graph with escaped metadata values", %{
    sample_video: sample_video
  }) do
    escaped_value = ~S(hello, [world]; it's:ok\fine)

    graph =
      FFix.graph(
        outputs: [
          video:
            FFix.Graph.input(0, :video)
            |> Filter.scale(w: 160, h: -1)
            |> Filter.metadata(mode: :add, key: "comment", value: escaped_value),
          audio:
            FFix.Graph.input(0, :audio)
            |> Filter.ametadata(mode: :add, key: "comment", value: escaped_value)
        ]
      )

    rendered = FFix.to_filtergraph(graph)
    parsed = Graph.parse!(rendered)
    assert FFix.to_filtergraph(parsed) == rendered

    command =
      FFix.command(
        [FFix.output([parsed[:video], parsed[:audio]], "-", f: :null, t: 0.1, "frames:v": 1)],
        global: ffmpeg_globals(),
        inputs: [FFix.input(sample_video)]
      )

    run_ffmpeg!(command)
  end

  test("runs a multi-output command with graph exports and direct input audio", %{
    tmp_dir: tmp_dir,
    sample_video: sample_video
  }) do
    src = FFix.input(sample_video)
    [master, preview] = Filter.split(FFix.video(src, 0), outputs: 2)

    graph =
      FFix.graph(
        outputs: [
          master: master |> Filter.scale(w: 160, h: -1),
          preview: preview |> Filter.scale(w: 80, h: -1)
        ]
      )

    master_path = Path.join(tmp_dir, "master.mp4")
    thumb_pattern = Path.join(tmp_dir, "thumb-%03d.jpg")
    thumb_path = Path.join(tmp_dir, "thumb-001.jpg")

    command =
      FFix.command(
        [
          FFix.output(
            [
              graph[:master],
              FFix.audio(src, 0)
            ],
            master_path,
            vcodec: :mpeg4,
            acodec: :aac,
            shortest: :flag,
            t: 0.25
          ),
          FFix.output(graph[:preview], thumb_pattern, [
            {"frames:v", 1},
            {"q:v", 3},
            f: :image2,
            an: :flag
          ])
        ],
        global: ffmpeg_globals(),
        inputs: [src]
      )

    run_ffmpeg!(command)
    assert_nonempty_file!(master_path)
    assert_nonempty_file!(thumb_path)
    assert ["video", "audio"] == probe_codec_types!(master_path)
    assert ["video"] == probe_codec_types!(thumb_path)
  end

  test("runs independently selected codecs after copied audio", %{
    tmp_dir: tmp_dir,
    sample_video: sample_video
  }) do
    input = FFix.input(sample_video)
    input = %{input | decoders: %{{:video, 0} => %Decoder{name: "mpeg4", options: [threads: 1]}}}
    output_path = Path.join(tmp_dir, "two-encodes.mkv")

    output = %Output{
      target: output_path,
      mappings: [
        %Mapping{source: FFix.audio(input, 0), encoding: :copy},
        %Mapping{
          source: FFix.video(input, 0),
          encoding: %Encoder{
            name: "mpeg4",
            options: [b: 300_000, threads: 1, data_partitioning: false]
          }
        },
        %Mapping{
          source: FFix.video(input, 0),
          encoding: %Encoder{name: "ffv1", options: [level: 3, threads: 1]}
        }
      ],
      muxer: %Muxer{name: "matroska", options: [cluster_time_limit: 500]},
      options: [t: 0.3]
    }

    command = %Command{global_options: ffmpeg_globals(), inputs: [input], outputs: [output]}
    run_ffmpeg!(command)
    assert_nonempty_file!(output_path)
    assert probe_stream_field!(output_path, "codec_name") == ["aac", "mpeg4", "ffv1"]
  end

  test("shortcut pipeline runs demuxing, decoding, filtered encodes, and independent muxers", %{
    tmp_dir: tmp_dir,
    sample_video: sample_video
  }) do
    input =
      Demuxer.mov(sample_video, ignore_editlist: true) |> Decoder.mpeg4({:video, 0}, threads: 1)

    main_path = Path.join(tmp_dir, "shortcuts.mp4")
    preview_path = Path.join(tmp_dir, "shortcuts-preview.mkv")
    [main, preview] = Filter.split(FFix.video(input, 0), outputs: 2)
    preview = Filter.scale(preview, w: 80, h: 48)
    graph = FFix.graph(outputs: [main: main, preview: preview])

    command =
      FFix.command(
        [
          Muxer.mp4(
            [
              Encoder.mpeg4(graph[:main], b: 300_000, threads: 1),
              FFix.stream_copy(FFix.audio(input, 0))
            ],
            main_path,
            movflags: [:faststart],
            empty_hdlr_name: true,
            output_options: [t: 0.3]
          ),
          Muxer.matroska(
            [Encoder.mpeg4(graph[:preview], b: 200_000, threads: 1, data_partitioning: true)],
            preview_path,
            output_options: [t: 0.3]
          )
        ],
        global: ffmpeg_globals()
      )

    run_ffmpeg!(command)
    assert probe_stream_field!(main_path, "codec_name") == ["mpeg4", "aac"]
    assert probe_stream_field!(preview_path, "codec_name") == ["mpeg4"]
    assert probe_dimensions!(preview_path) == {80, 48}
  end

  test("rawvideo demuxer and image output shortcuts preserve an explicit input format", %{
    tmp_dir: tmp_dir
  }) do
    raw_path = Path.join(tmp_dir, "frame.rgb")
    png_path = Path.join(tmp_dir, "frame.png")
    File.write!(raw_path, :binary.copy(<<255, 0, 0>>, 16 * 16))

    input =
      Demuxer.rawvideo(raw_path, video_size: "16x16", pixel_format: :rgb24, framerate: 1)
      |> Decoder.rawvideo({:video, 0}, threads: 1)

    command =
      FFix.command(Muxer.image2([Encoder.png(FFix.video(input, 0))], png_path, update: true),
        global: ffmpeg_globals()
      )

    run_ffmpeg!(command)
    assert probe_dimensions!(png_path) == {16, 16}
  end

  test("HLS callbacks preserve rendition references after audio/video mappings are reordered", %{
    tmp_dir: tmp_dir,
    sample_video: sample_video
  }) do
    source = FFix.input(sample_video)
    [high, low] = Filter.split(FFix.video(source, 0), outputs: 2)
    high = Encoder.mpeg4(high, b: "300k", g: 1, threads: 1)
    low = low |> Filter.scale(w: 80, h: 48) |> Encoder.mpeg4(b: "150k", g: 1, threads: 1)
    sound = Encoder.aac(FFix.audio(source, 0), b: "64k", threads: 1)

    command =
      FFix.command(
        Muxer.hls(
          [high: high, low: low, sound: sound],
          Path.join(tmp_dir, "%v.m3u8"),
          # FFmpeg omits segments <= 0.5s from peak-bandwidth calculations.
          hls_time: 1,
          master_pl_name: "master.m3u8",
          var_stream_map: fn streams ->
            "#{streams.high.specifier},agroup:a,name:high " <>
              "#{streams.low.specifier},agroup:a,name:low " <>
              "#{streams.sound.specifier},agroup:a,name:audio,default:yes"
          end
        ),
        global: ffmpeg_globals()
      )

    [output] = command.outputs
    [high, low, sound] = output.mappings
    output = %{output | mappings: [sound, low, high]}
    command = %{command | outputs: [output]}
    result = run_ffmpeg!(command)
    master = File.read!(Path.join(tmp_dir, "master.m3u8"))
    assert master =~ ~s(TYPE=AUDIO,GROUP-ID="group_a")
    assert master =~ ~s(URI="audio.m3u8")

    assert master =~ ~r/RESOLUTION=160x90[^\n]*\nhigh\.m3u8/,
           result.shell <> "\n" <> result.stderr

    assert master =~ ~r/RESOLUTION=80x48[^\n]*\nlow\.m3u8/
    assert length(Regex.scan(~r/#EXT-X-MEDIA:TYPE=AUDIO/, master)) == 1

    for name <- ["high", "low", "audio"] do
      playlist = File.read!(Path.join(tmp_dir, "#{name}.m3u8"))
      assert playlist =~ "#EXTINF:"
      assert playlist =~ "#EXT-X-ENDLIST"
    end
  end

  test "runner streams raw ffmpeg stderr and grouped progress updates" do
    command = runner_observation_command()

    events =
      FFix.stream(command, ffmpeg: @ffmpeg, progress: true, stderr: :collect) |> Enum.to_list()

    assert Enum.any?(events, fn
             {:progress, %FFix.Runner.Progress{status: :end}} -> true
             _ -> false
           end)

    assert {:exit, result} = List.last(events)
    assert result.exit_status == 0

    stderr =
      events
      |> Enum.flat_map(fn
        {:stderr, chunk} -> [chunk]
        _event -> []
      end)
      |> IO.iodata_to_binary()

    assert result.stderr == stderr
    assert result.stderr =~ "[info]"
    assert %FFix.Runner.Progress{status: :end} = result.last_progress
    assert result.last_progress.frame >= 1
  end

  defp create_sample_video!(path) do
    {output, status} =
      System.cmd(
        @ffmpeg,
        [
          "-y",
          "-nostdin",
          "-loglevel",
          "error",
          "-threads",
          "1",
          "-f",
          "lavfi",
          "-i",
          "testsrc2=size=160x90:rate=10:duration=1",
          "-f",
          "lavfi",
          "-i",
          "sine=frequency=880:sample_rate=48000:duration=1",
          "-shortest",
          "-c:v",
          "mpeg4",
          "-q:v",
          "5",
          "-pix_fmt",
          "yuv420p",
          "-c:a",
          "aac",
          path
        ],
        stderr_to_stdout: true
      )

    assert status == 0,
           "failed to create integration sample fixture at #{path}
output:
#{output}"

    assert_nonempty_file!(path)
  end

  defp ffmpeg_globals do
    [y: :flag, nostdin: :flag, loglevel: :error, threads: 1, filter_threads: 1]
  end

  defp runner_observation_command do
    FFix.command(
      [
        FFix.output(
          FFix.Graph.input(0, {:video, 0}),
          "-",
          f: :null
        )
      ],
      global: [nostdin: :flag, loglevel: "level+info", stats_period: 0.1, threads: 1],
      inputs: [FFix.input("testsrc=size=16x16:rate=10:duration=0.3", f: :lavfi)]
    )
  end

  defp run_ffmpeg!(command), do: FFix.run!(command, ffmpeg: @ffmpeg, stderr: :collect)

  defp probe_codec_types!(path), do: probe_stream_field!(path, "codec_type")

  defp probe_stream_field!(path, field) do
    {output, 0} =
      System.cmd(
        @ffprobe,
        ["-v", "error", "-show_entries", "stream=#{field}", "-of", "csv=p=0", path],
        stderr_to_stdout: true
      )

    String.split(output, "\n", trim: true)
  end

  defp probe_dimensions!(path) do
    {output, 0} =
      System.cmd(
        @ffprobe,
        ["-v", "error", "-show_entries", "stream=width,height", "-of", "csv=p=0:s=x", path],
        stderr_to_stdout: true
      )

    output
    |> String.trim()
    |> String.split("x", parts: 2)
    |> then(fn [width, height] -> {String.to_integer(width), String.to_integer(height)} end)
  end

  defp assert_nonempty_file!(path) do
    assert File.exists?(path), "expected output file #{path} to exist"
    assert File.stat!(path).size > 0, "expected output file #{path} to be non-empty"
  end
end
