defmodule FF.CommandTest do
  use ExUnit.Case, async: true

  alias FF.Command
  alias FF.Filter

  test "graphs support access by named and positional outputs" do
    video = FF.input(0, :video)
    [master, preview] = Filter.split(video, outputs: 2)
    graph = FF.graph(outputs: [master: master, preview: preview])

    assert graph[:master] == FF.Graph.export!(graph, :master)
    assert graph[0] == graph[:master]
    assert graph[1] == graph[:preview]
    assert graph[:missing] == nil
    assert graph[2] == nil
  end

  test "builds argv with inline graph output shorthands" do
    audio = Command.input_stream(0, :audio)

    command =
      FF.command(
        inputs: [Command.input("input.mp4")],
        graph:
          FF.graph(
            outputs: [
              master:
                FF.input(0, :video)
                |> Filter.scale(w: 1280, h: -1),
              preview:
                FF.input(0, :video)
                |> Filter.scale(w: 320, h: -1)
                |> Filter.fps(fps: 1)
            ]
          ),
        outputs: [
          Command.output("master.mp4", [:master, audio], vcodec: :libx264, acodec: :aac),
          Command.output("thumb-%03d.jpg", 1, f: :image2, vsync: 0)
        ]
      )

    assert FF.to_argv(command) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-filter_complex",
             "[0:v]scale=w=1280:h=-1[master];\n[0:v]scale=w=320:h=-1[scale_1_0];\n[scale_1_0]fps=fps=1[preview];",
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

  test "rejects graph output shorthands without a command graph" do
    command = FF.command(outputs: [Command.output("out.mp4", :preview)])

    assert_raise ArgumentError, "output source :preview requires a command graph", fn ->
      FF.to_argv(command)
    end
  end

  test "rejects missing inline graph output shorthands" do
    command =
      FF.command(
        inputs: [Command.input("input.mp4")],
        graph: FF.graph(outputs: [video: FF.input(0, :video)]),
        outputs: [Command.output("out.mp4", :preview)]
      )

    assert_raise ArgumentError, "command graph has no output :preview", fn ->
      FF.to_argv(command)
    end
  end

  test "builds argv with labeled command inputs" do
    src = Command.input("input.mp4", label: :src)
    logo = Command.input("logo.png", label: :logo)

    command =
      FF.command(
        inputs: [src, logo],
        graph:
          FF.graph(
            outputs: [
              video:
                src[:video]
                |> Filter.overlay(logo[:video], x: 20, y: 20)
            ]
          ),
        outputs: [
          Command.output("out.mp4", [:video, src[:audio]], vcodec: :libx264, acodec: :aac)
        ]
      )

    assert FF.to_argv(command) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-i",
             "logo.png",
             "-filter_complex",
             "[0:v][1:v]overlay=x=20:y=20[video];",
             "-map",
             "[video]",
             "-map",
             "0:a",
             "-vcodec",
             "libx264",
             "-acodec",
             "aac",
             "out.mp4"
           ]
  end

  test "input access supports indexed tracks" do
    src = Command.input("input.mp4", label: :src)

    command =
      FF.command(
        inputs: [src],
        outputs: [Command.output("out.mka", src[audio: 1], acodec: :copy)]
      )

    assert FF.to_argv(command) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-map",
             "0:a:1",
             "-acodec",
             "copy",
             "out.mka"
           ]
  end

  test "input_stream/2 accepts command input declarations" do
    src = Command.input("input.mp4")

    command =
      FF.command(
        inputs: [src],
        outputs: [
          Command.output("out.mka", Command.input_stream(src, {:audio, 1}), acodec: :copy)
        ]
      )

    assert FF.to_argv(command) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-map",
             "0:a:1",
             "-acodec",
             "copy",
             "out.mka"
           ]
  end

  test "supports access on unlabeled command inputs" do
    src = Command.input("input.mp4")

    command =
      FF.command(
        inputs: [src],
        outputs: [Command.output("out.mp4", src[:video], vcodec: :copy)]
      )

    assert FF.to_argv(command) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-map",
             "0:v",
             "-vcodec",
             "copy",
             "out.mp4"
           ]
  end

  test "rejects duplicate command input declarations" do
    src = Command.input("input.mp4")

    assert_raise ArgumentError, "duplicate command input declaration", fn ->
      FF.command(
        inputs: [src, src],
        outputs: [Command.output("out.mp4", src[:video], vcodec: :copy)]
      )
      |> FF.to_argv()
    end
  end

  test "rejects duplicate command input labels" do
    assert_raise ArgumentError, "duplicate command input label \"src\"", fn ->
      FF.command(
        inputs: [
          Command.input("a.mp4", label: :src),
          Command.input("b.mp4", label: "src")
        ],
        outputs: [Command.output("out.mp4", Command.input_stream(0, :video))]
      )
      |> FF.to_argv()
    end
  end

  test "rejects missing labeled inputs" do
    command =
      FF.command(
        inputs: [Command.input("input.mp4", label: :src)],
        graph: FF.graph(outputs: [video: FF.input(:missing, :video)]),
        outputs: [Command.output("out.mp4", :video)]
      )

    assert_raise ArgumentError, ~s(input "missing" is not declared in the command), fn ->
      FF.to_argv(command)
    end
  end

  test "builds argv with input options" do
    command =
      FF.command(
        global: [y: true],
        inputs: [
          Command.input("input.mp4", ss: "00:00:03", stream_loop: -1),
          Command.input("logo.png", loop: 1, framerate: 1)
        ],
        outputs: [Command.output("out.mp4", Command.input_stream(0, :video), vcodec: :copy)]
      )

    assert FF.to_argv(command) == [
             "ffmpeg",
             "-y",
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
             "0:v",
             "-vcodec",
             "copy",
             "out.mp4"
           ]
  end

  test "builds argv from command, input, and output constructors" do
    video =
      FF.input(0, :video)
      |> Filter.scale(w: 1280, h: -1)
      |> Filter.drawtext(text: "Hello", x: FF.expr("w-tw-20"), y: 20)

    graph = FF.graph(outputs: [video: video])
    audio = Command.input_stream(0, :audio)

    command =
      FF.command(
        global: [y: true, loglevel: :error],
        inputs: [Command.input("input.mp4")],
        graph: graph,
        outputs: [
          Command.output("out.mp4", [graph[:video], audio], vcodec: :libx264, acodec: :copy)
        ]
      )

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

    command =
      FF.command()
      |> Command.input("input.mp4")
      |> Command.graph(graph)
      |> Command.output("out.mp4", graph[:raw], vcodec: :copy)

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

    command =
      FF.command()
      |> Command.input("input file.mp4")
      |> Command.graph(graph)
      |> Command.output("out file.mp4", graph[:video], vcodec: :libx264)

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
      |> Command.output("out.mp4", graph[:video], vcodec: :libx264)

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
    audio = Command.input_stream(0, :audio)

    command =
      FF.command()
      |> Command.input("input.mp4")
      |> Command.graph(graph)
      |> Command.output("master.mp4", [graph[:master], audio], vcodec: :libx264, acodec: :aac)
      |> Command.output("thumb-%03d.jpg", graph[:preview], f: :image2, vsync: 0)

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
