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

  test "runs a branching graph and writes the expected stacked frame", %{
    tmp_dir: tmp_dir,
    sample_video: sample_video
  } do
    src = Command.input(sample_video)

    scaled = src[:video] |> Filter.scale(w: 96, h: -1)
    [left, right] = Filter.split(scaled, outputs: 2)
    stacked = Filter.hstack([left, Filter.hflip(right)])

    output_pattern = Path.join(tmp_dir, "stacked-%03d.jpg")
    output_file = Path.join(tmp_dir, "stacked-001.jpg")

    command =
      FFix.command(
        global: ffmpeg_globals(),
        inputs: [src: src],
        graph: FFix.graph(outputs: [stacked: stacked]),
        outputs: [
          Command.output(output_pattern, :stacked, [
            {"frames:v", 1},
            {"q:v", 3},
            {:f, :image2},
            {:an, true}
          ])
        ]
      )

    run_ffmpeg!(command)

    assert_nonempty_file!(output_file)
    assert {192, 54} == probe_dimensions!(output_file)
  end

  test "accepts a parsed round-tripped graph with escaped metadata values", %{
    sample_video: sample_video
  } do
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
        global: ffmpeg_globals(),
        inputs: [src: Command.input(sample_video)],
        graph: parsed,
        outputs: [
          Command.output("-", [parsed[:video], parsed[:audio]], f: :null, t: 0.1, "frames:v": 1)
        ]
      )

    run_ffmpeg!(command)
  end

  test "runs a multi-output command with graph exports and direct input audio", %{
    tmp_dir: tmp_dir,
    sample_video: sample_video
  } do
    src = Command.input(sample_video)
    [master, preview] = Filter.split(src[:video], outputs: 2)

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
        global: ffmpeg_globals(),
        inputs: [src: src],
        graph: graph,
        outputs: [
          Command.output(master_path, [graph[:master], src[audio: 0]],
            vcodec: :mpeg4,
            acodec: :aac,
            shortest: true,
            t: 0.25
          ),
          Command.output(thumb_pattern, :preview, [
            {"frames:v", 1},
            {"q:v", 3},
            {:f, :image2},
            {:an, true}
          ])
        ]
      )

    run_ffmpeg!(command)

    assert_nonempty_file!(master_path)
    assert_nonempty_file!(thumb_path)
    assert ["video", "audio"] == probe_codec_types!(master_path)
    assert ["video"] == probe_codec_types!(thumb_path)
  end

  test "omits filter_complex for graphs that only export direct input streams", %{
    tmp_dir: tmp_dir,
    sample_video: sample_video
  } do
    src = Command.input(sample_video)
    graph = FFix.graph(outputs: [video: src[:video], audio: src[:audio]])
    output_path = Path.join(tmp_dir, "copy.mp4")

    command =
      FFix.command(
        global: ffmpeg_globals(),
        inputs: [src: src],
        graph: graph,
        outputs: [
          Command.output(output_path, [graph[:video], graph[:audio]],
            vcodec: :copy,
            acodec: :copy
          )
        ]
      )

    refute Enum.member?(FFix.to_argv(command), "-filter_complex")

    run_ffmpeg!(command)

    assert_nonempty_file!(output_path)
    assert ["video", "audio"] == probe_codec_types!(output_path)
  end

  test "runs separately configured encodes of one input after copied audio", %{
    tmp_dir: tmp_dir,
    sample_video: sample_video
  } do
    input = Command.input(sample_video)
    input = %{input | decoders: %{{:video, 0} => %Decoder{name: "mpeg4", options: [threads: 1]}}}
    output_path = Path.join(tmp_dir, "two-encodes.mkv")

    output = %Output{
      target: output_path,
      mappings: [
        %Mapping{source: input[audio: 0], encoding: :copy},
        %Mapping{
          source: input[video: 0],
          encoding: %Encoder{
            name: "mpeg4",
            options: [b: 300_000, threads: 1, data_partitioning: false]
          }
        },
        %Mapping{
          source: input[video: 0],
          encoding: %Encoder{
            name: "mpeg4",
            options: [b: 600_000, threads: 1, data_partitioning: true]
          }
        }
      ],
      muxer: %Muxer{name: "matroska", options: [cluster_time_limit: 500]},
      options: [t: 0.3]
    }

    command = %Command{global_options: ffmpeg_globals(), inputs: [input], outputs: [output]}
    run_ffmpeg!(command)

    assert_nonempty_file!(output_path)
    assert probe_codec_types!(output_path) == ["audio", "video", "video"]
  end

  test "runs configured filter exports through independent encoders and muxers", %{
    tmp_dir: tmp_dir,
    sample_video: sample_video
  } do
    input = Command.input(sample_video)
    [master, preview] = Filter.split(input[video: 0], outputs: 2)
    preview = Filter.scale(preview, w: 80, h: 48)
    graph = FFix.graph(outputs: [master: master, preview: preview])

    encoder = %Encoder{name: "mpeg4", options: [b: 300_000, threads: 1]}
    master_path = Path.join(tmp_dir, "configured-master.mp4")
    preview_path = Path.join(tmp_dir, "configured-preview.mkv")

    master_output = %Output{
      target: master_path,
      mappings: [
        %Mapping{source: graph[:master], encoding: encoder},
        %Mapping{source: input[audio: 0], encoding: :copy}
      ],
      muxer: %Muxer{name: "mp4", options: [movflags: "faststart", empty_hdlr_name: true]},
      options: [t: 0.3]
    }

    preview_output = %Output{
      target: preview_path,
      mappings: [%Mapping{source: graph[:preview], encoding: encoder}],
      muxer: %Muxer{name: "matroska"},
      options: [t: 0.3]
    }

    command = %Command{
      global_options: ffmpeg_globals(),
      inputs: [input],
      graph: graph,
      outputs: [master_output, preview_output]
    }

    run_ffmpeg!(command)

    assert_nonempty_file!(master_path)
    assert_nonempty_file!(preview_path)
    assert probe_codec_types!(master_path) == ["video", "audio"]
    assert probe_dimensions!(preview_path) == {80, 48}
  end

  test "shortcut pipeline runs demuxing, decoding, filtered encodes, and independent muxers", %{
    tmp_dir: tmp_dir,
    sample_video: sample_video
  } do
    input = Demuxer.mov(sample_video, ignore_editlist: true) |> Decoder.mpeg4(threads: 1)
    main_path = Path.join(tmp_dir, "shortcuts.mp4")
    preview_path = Path.join(tmp_dir, "shortcuts-preview.mkv")

    command =
      FFix.command(
        input,
        fn source ->
          [main, preview] = Filter.split(FFix.video(source), outputs: 2)
          preview = Filter.scale(preview, w: 80, h: 48)

          [
            Muxer.mp4(main_path,
              video: Encoder.mpeg4(main, b: 300_000, threads: 1),
              audio: FFix.stream_copy(FFix.audio(source)),
              movflags: [:faststart],
              empty_hdlr_name: true,
              output_options: [t: 0.3]
            ),
            Muxer.matroska(preview_path,
              video: Encoder.mpeg4(preview, b: 200_000, threads: 1, data_partitioning: true),
              output_options: [t: 0.3]
            )
          ]
        end,
        global: ffmpeg_globals()
      )

    run_ffmpeg!(command)
    assert probe_codec_types!(main_path) == ["video", "audio"]
    assert probe_dimensions!(preview_path) == {80, 48}
  end

  test "rawvideo demuxer and image output shortcuts preserve an explicit input format", %{
    tmp_dir: tmp_dir
  } do
    raw_path = Path.join(tmp_dir, "frame.rgb")
    png_path = Path.join(tmp_dir, "frame.png")
    File.write!(raw_path, :binary.copy(<<255, 0, 0>>, 16 * 16))

    input =
      Demuxer.rawvideo(raw_path, video_size: "16x16", pixel_format: :rgb24, framerate: 1)
      |> Decoder.rawvideo(threads: 1)

    command =
      FFix.command(
        input,
        fn source ->
          Muxer.image2(png_path, video: Encoder.png(FFix.video(source)), update: true)
        end,
        global: ffmpeg_globals()
      )

    run_ffmpeg!(command)
    assert probe_dimensions!(png_path) == {16, 16}
  end

  test "runner parses ffmpeg logs and progress events" do
    parent = self()
    command = runner_observation_command()

    result =
      FFix.run!(command,
        progress: true,
        stderr: :collect,
        on_event: fn event -> send(parent, event) end
      )

    assert result.exit_status == 0
    assert result.stderr =~ "[info]"
    assert Enum.any?(result.logs, &(&1.level == :info))
    assert %FFix.Runner.Progress{status: :end} = result.last_progress
    assert result.last_progress.frame >= 1

    events = collect_runner_events([])

    assert Enum.any?(events, fn
             {:log, %FFix.Runner.Log{level: :info}} -> true
             _ -> false
           end)

    assert Enum.any?(events, fn
             {:progress, %FFix.Runner.Progress{status: :end}} -> true
             _ -> false
           end)
  end

  test "runner streams ffmpeg logs and progress events" do
    command = runner_observation_command()

    events =
      FFix.stream(command, progress: true, stderr: :collect)
      |> Enum.to_list()

    assert Enum.any?(events, fn
             {:log, %FFix.Runner.Log{level: :info}} -> true
             _ -> false
           end)

    assert Enum.any?(events, fn
             {:progress, %FFix.Runner.Progress{status: :end}} -> true
             _ -> false
           end)

    assert {:exit, result} = List.last(events)
    assert result.exit_status == 0
    assert result.stderr =~ "[info]"
    assert %FFix.Runner.Progress{status: :end} = result.last_progress
  end

  test "runner stderr discard suppresses ffmpeg log and progress events" do
    parent = self()
    command = runner_observation_command()

    result =
      FFix.run!(command,
        progress: true,
        stderr: :discard,
        on_event: fn event -> send(parent, event) end
      )

    assert result.exit_status == 0
    assert result.stderr == nil
    assert result.logs == []
    assert result.last_progress == nil

    events = collect_runner_events([])

    refute Enum.any?(events, fn
             {:stderr, _} -> true
             {:log, _} -> true
             {:progress, _} -> true
             _ -> false
           end)
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
           "failed to create integration sample fixture at #{path}\noutput:\n#{output}"

    assert_nonempty_file!(path)
  end

  defp ffmpeg_globals do
    [
      y: true,
      nostdin: true,
      loglevel: :error,
      threads: 1,
      filter_threads: 1
    ]
  end

  defp runner_observation_command do
    FFix.command(
      global: [nostdin: true, loglevel: "level+info", stats_period: 0.1, threads: 1],
      inputs: [src: Command.input("testsrc=size=16x16:rate=10:duration=0.3", f: :lavfi)],
      outputs: [Command.output("-", FFix.Graph.input(0, :video), f: :null)]
    )
  end

  defp run_ffmpeg!(command) do
    result = FFix.run!(command, stderr: :collect)

    assert result.exit_status == 0,
           "ffmpeg failed with exit #{inspect(result.exit_status)}\ncommand: #{result.shell}\noutput:\n#{result.stderr}"

    result
  end

  defp probe_codec_types!(path) do
    {output, 0} =
      System.cmd(
        @ffprobe,
        ["-v", "error", "-show_entries", "stream=codec_type", "-of", "csv=p=0", path],
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

  defp collect_runner_events(events) do
    receive do
      event -> collect_runner_events([event | events])
    after
      0 -> Enum.reverse(events)
    end
  end

  defp assert_nonempty_file!(path) do
    assert File.exists?(path), "expected output file #{path} to exist"
    assert File.stat!(path).size > 0, "expected output file #{path} to be non-empty"
  end
end
