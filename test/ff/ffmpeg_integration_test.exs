defmodule FF.FFmpegIntegrationTest do
  use ExUnit.Case, async: false

  alias FF.Command
  alias FF.Filter
  alias FF.Graph

  @moduletag :integration

  @sample_video Path.expand("../support/sample.mp4", __DIR__)
  @ffmpeg System.find_executable("ffmpeg") || raise("ffmpeg is required for integration tests")
  @ffprobe System.find_executable("ffprobe") || raise("ffprobe is required for integration tests")

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "ff-integration-#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    {:ok, tmp_dir: tmp_dir}
  end

  test "runs a branching graph and writes the expected stacked frame", %{tmp_dir: tmp_dir} do
    src = Command.input(@sample_video, ss: "00:00:01")

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

  test "accepts a parsed round-tripped graph with escaped metadata values" do
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
        inputs: [Command.input(@sample_video, ss: "00:00:01")],
        graph: parsed,
        outputs: [
          Command.output("-", [parsed[:video], parsed[:audio]], f: :null, t: 0.1, "frames:v": 1)
        ]
      )

    run_ffmpeg!(command)
  end

  test "runs a multi-output command with graph exports and direct input audio", %{
    tmp_dir: tmp_dir
  } do
    src = Command.input(@sample_video, ss: "00:00:01")
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
            vcodec: :libx264,
            preset: :ultrafast,
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
