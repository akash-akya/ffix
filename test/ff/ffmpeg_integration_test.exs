defmodule FF.FFmpegIntegrationTest do
  use ExUnit.Case, async: false

  alias FF.Command
  alias FF.Filter
  alias FF.Graph

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
        "ff-integration-fixtures-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(fixture_dir)

    sample_video = Path.join(fixture_dir, "sample.mp4")
    create_sample_video!(sample_video)

    on_exit(fn -> File.rm_rf!(fixture_dir) end)

    {:ok, sample_video: sample_video}
  end

  setup context do
    tmp_dir = Path.join(System.tmp_dir!(), "ff-integration-#{System.unique_integer([:positive])}")
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
      FF.command(
        global: ffmpeg_globals(),
        inputs: [src],
        graph: FF.graph(outputs: [stacked: stacked]),
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
      FF.graph(
        outputs: [
          video:
            FF.input(0, :video)
            |> Filter.scale(w: 160, h: -1)
            |> Filter.metadata(mode: :add, key: "comment", value: escaped_value),
          audio:
            FF.input(0, :audio)
            |> Filter.ametadata(mode: :add, key: "comment", value: escaped_value)
        ]
      )

    rendered = FF.to_filtergraph(graph)
    parsed = Graph.parse!(rendered)

    assert FF.to_filtergraph(parsed) == rendered

    command =
      FF.command(
        global: ffmpeg_globals(),
        inputs: [Command.input(sample_video)],
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
      FF.graph(
        outputs: [
          master: master |> Filter.scale(w: 160, h: -1),
          preview: preview |> Filter.scale(w: 80, h: -1)
        ]
      )

    master_path = Path.join(tmp_dir, "master.mp4")
    thumb_pattern = Path.join(tmp_dir, "thumb-%03d.jpg")
    thumb_path = Path.join(tmp_dir, "thumb-001.jpg")

    command =
      FF.command(
        global: ffmpeg_globals(),
        inputs: [src],
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

  defp run_ffmpeg!(command) do
    argv = FF.to_argv(command)
    {output, status} = System.cmd(@ffmpeg, tl(argv), stderr_to_stdout: true)

    assert status == 0,
           "ffmpeg failed with exit #{status}\ncommand: #{FF.to_shell_string(command)}\noutput:\n#{output}"

    output
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

  defp assert_nonempty_file!(path) do
    assert File.exists?(path), "expected output file #{path} to exist"
    assert File.stat!(path).size > 0, "expected output file #{path} to be non-empty"
  end
end
