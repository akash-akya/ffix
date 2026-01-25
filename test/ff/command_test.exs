defmodule FF.CommandTest do
  use ExUnit.Case, async: true

  alias FF.Command
  alias FF.Filter

  test "builds argv for one output using a graph export and input audio" do
    video =
      FF.input(0, :video)
      |> Filter.scale(w: 1280, h: -1)
      |> Filter.drawtext(text: "Hello", x: FF.expr("w-tw-20"), y: 20)

    graph = FF.graph(outputs: [video: video])
    video = FF.Graph.export!(graph, :video)
    audio = Command.input_stream(0, :audio)

    command =
      FF.command()
      |> Command.global(y: true, loglevel: :error)
      |> Command.input("input.mp4")
      |> Command.graph(graph)
      |> Command.output("out.mp4", [video, audio], vcodec: :libx264, acodec: :copy)

    assert FF.to_argv(command) == [
             "ffmpeg",
             "-y",
             "-loglevel",
             "error",
             "-i",
             "input.mp4",
             "-filter_complex",
             "[0:v]scale=w=1280:h=-1[scale_0];\n[scale_0]drawtext=text=Hello:x=w-tw-20:y=20[video];",
             "-map",
             "[video]",
             "-map",
             "0:a",
             "-vcodec",
             "libx264",
             "-acodec",
             "copy",
             "out.mp4"
           ]
  end

  test "maps graph exports backed by inputs as input stream refs" do
    graph = FF.graph(outputs: [raw: FF.input(0, :video)])
    raw = FF.Graph.export!(graph, :raw)

    command =
      FF.command()
      |> Command.input("input.mp4")
      |> Command.graph(graph)
      |> Command.output("out.mp4", raw, vcodec: :copy)

    assert FF.to_argv(command) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-filter_complex",
             "",
             "-map",
             "0:v",
             "-vcodec",
             "copy",
             "out.mp4"
           ]
  end

  test "renders a shell-safe command string for debugging" do
    video =
      FF.input(0, :video)
      |> Filter.scale(w: 1280, h: -1)
      |> Filter.drawtext(text: "hello world", x: FF.expr("w-tw-20"), y: 20)

    graph = FF.graph(outputs: [video: video])
    video = FF.Graph.export!(graph, :video)

    command =
      FF.command()
      |> Command.input("input file.mp4")
      |> Command.graph(graph)
      |> Command.output("out file.mp4", video, vcodec: :libx264)

    shell = FF.to_shell_string(command)

    assert shell =~ "ffmpeg"
    assert shell =~ "-i 'input file.mp4'"
    assert shell =~ "-filter_complex '"
    assert shell =~ "'out file.mp4'"
  end

  test "rejects input refs that do not exist in the command" do
    graph = FF.graph(outputs: [video: FF.input(1, :video)])

    command =
      FF.command()
      |> Command.input("input.mp4")
      |> Command.graph(graph)
      |> Command.output("out.mp4", FF.Graph.export!(graph, :video), vcodec: :libx264)

    assert_raise ArgumentError, "input 1 is not declared in the command", fn ->
      FF.to_argv(command)
    end
  end

  test "builds argv for multiple outputs from one graph" do
    video = FF.input(0, :video)
    [master, preview] = Filter.split(video, outputs: 2)

    preview =
      preview
      |> Filter.fps(fps: 1)
      |> Filter.scale(w: 320, h: -1)

    graph = FF.graph(outputs: [master: master, preview: preview])
    master = FF.Graph.export!(graph, :master)
    preview = FF.Graph.export!(graph, :preview)
    audio = Command.input_stream(0, :audio)

    command =
      FF.command()
      |> Command.input("input.mp4")
      |> Command.graph(graph)
      |> Command.output("master.mp4", [master, audio], vcodec: :libx264, acodec: :aac)
      |> Command.output("thumb-%03d.jpg", preview, f: :image2, vsync: 0)

    assert FF.to_argv(command) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-filter_complex",
             "[0:v]split=outputs=2[master][split_1];\n[split_1]fps=fps=1[fps_0];\n[fps_0]scale=w=320:h=-1[preview];",
             "-map",
             "[master]",
             "-map",
             "0:a",
             "-vcodec",
             "libx264",
             "-acodec",
             "aac",
             "master.mp4",
             "-map",
             "[preview]",
             "-f",
             "image2",
             "-vsync",
             "0",
             "thumb-%03d.jpg"
           ]
  end
end
