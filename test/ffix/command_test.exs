defmodule FFix.CommandTest do
  use ExUnit.Case, async: true

  alias FFix.{Command, Filter}

  test "builds argv with independently declared inputs" do
    source = FFix.input("input.mp4")
    logo = FFix.input("logo.png")
    picture = Filter.overlay(FFix.video(source, 0), FFix.video(logo, 0), x: 20, y: 20)

    command =
      FFix.command(
        FFix.output([video: picture, audio: FFix.audio(source, 0)], "out.mp4",
          vcodec: :libx264,
          acodec: :aac
        )
      )

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-i",
             "logo.png",
             "-filter_complex",
             "[0:v:0][1:v:0]overlay=x=20:y=20[out0];",
             "-map",
             "[out0]",
             "-map",
             "0:a:0",
             "-vcodec",
             "libx264",
             "-acodec",
             "aac",
             "out.mp4"
           ]
  end

  test "builds argv with global and input options including unused explicit inputs" do
    source = FFix.input("input.mp4", ss: "00:00:03", stream_loop: -1)
    logo = FFix.input("logo.png", loop: 1, framerate: 1)

    command =
      FFix.command(FFix.output(FFix.video(source, 0), "out.mp4", vcodec: :copy),
        inputs: [source, logo],
        global: [y: :flag, loglevel: :error]
      )

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-y",
             "-loglevel",
             "error",
             "-ss",
             "00:00:03",
             "-stream_loop",
             "-1",
             "-i",
             "input.mp4",
             "-loop",
             "1",
             "-framerate",
             "1",
             "-i",
             "logo.png",
             "-map",
             "0:v:0",
             "-vcodec",
             "copy",
             "out.mp4"
           ]
  end

  test "appends configured declarations and outputs to an explicit graph command" do
    source = FFix.Demuxer.mov("input.mp4", input_options: [ss: 2])
    video = FFix.video(source, 0) |> Filter.scale(w: 1280, h: -1)
    graph = FFix.graph(outputs: [video: video])

    command =
      Command.new(global: [y: :flag], graph: graph)
      |> Command.add_input(source)
      |> Command.add_output(FFix.output(hd(graph.exports), "video.mp4", vcodec: :libx264))
      |> Command.add_output(FFix.output(FFix.audio(source, 0), "audio.mka", acodec: :copy))

    assert command.inputs == [source]

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-y",
             "-ss",
             "2",
             "-f",
             "mov",
             "-i",
             "input.mp4",
             "-filter_complex",
             "[0:v:0]scale=w=1280:h=-1[video];",
             "-map",
             "[video]",
             "-vcodec",
             "libx264",
             "video.mp4",
             "-map",
             "0:a:0",
             "-acodec",
             "copy",
             "audio.mka"
           ]
  end

  @tag skip: is_nil(System.find_executable("sh"))
  test "shell rendering preserves literal argv through POSIX shell parsing" do
    source = FFix.input("input's [draft].mp4")

    command =
      source
      |> FFix.video(0)
      |> FFix.output("out file.mp4", metadata: "title=$HOME; it's a test", metadata: "")
      |> FFix.command()

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-i",
             "input's [draft].mp4",
             "-map",
             "0:v:0",
             "-metadata",
             "title=$HOME; it's a test",
             "-metadata",
             "",
             "out file.mp4"
           ]

    shell = FFix.to_shell_string(command)
    script = "set -- #{shell}; printf '%s\\0' \"$@\""
    assert {output, 0} = System.cmd("sh", ["-c", script], stderr_to_stdout: true)
    assert output == Enum.map_join(FFix.to_argv(command), "", &(&1 <> "\0"))
  end

  test "builds argv for multiple outputs from one split graph" do
    source = FFix.input("input.mp4")
    [master, preview] = Filter.split(FFix.video(source, 0), outputs: 2)
    preview = preview |> Filter.fps(fps: 1) |> Filter.scale(w: 320, h: -1)
    graph = FFix.graph(outputs: [master: master, preview: preview])

    command =
      FFix.command([
        FFix.output([graph[:master], FFix.audio(source, 0)], "master.mp4",
          vcodec: :libx264,
          acodec: :aac
        ),
        FFix.output(graph[:preview], "thumb-%03d.jpg", f: :image2, vsync: 0)
      ])

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-filter_complex",
             "[0:v:0]split=outputs=2[out0][split_1];\n[split_1]fps=fps=1[fps_0];\n[fps_0]scale=w=320:h=-1[out2];",
             "-map",
             "[out0]",
             "-map",
             "0:a:0",
             "-vcodec",
             "libx264",
             "-acodec",
             "aac",
             "master.mp4",
             "-map",
             "[out2]",
             "-f",
             "image2",
             "-vsync",
             "0",
             "thumb-%03d.jpg"
           ]
  end
end
