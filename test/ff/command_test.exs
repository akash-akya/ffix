defmodule FF.CommandTest do
  use ExUnit.Case, async: true

  alias FF.Command
  alias FF.Filter

  test "graphs support access by named and positional outputs" do
    video = FF.Graph.input(0, :video)
    [master, preview] = Filter.split(video, outputs: 2)
    graph = FF.graph(outputs: [master: master, preview: preview])

    assert graph[:master] == FF.Graph.export!(graph, :master)
    assert graph[0] == graph[:master]
    assert graph[1] == graph[:preview]
    assert graph[:missing] == nil
    assert graph[2] == nil
  end

  test "builds argv with inline graph output shorthands" do
    audio = FF.Graph.input(0, :audio)

    command =
      FF.command(
        inputs: [src: Command.input("input.mp4")],
        graph:
          FF.graph(
            outputs: [
              master:
                FF.Graph.input(0, :video)
                |> Filter.scale(w: 1280, h: -1),
              preview:
                FF.Graph.input(0, :video)
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
        inputs: [src: Command.input("input.mp4")],
        graph: FF.graph(outputs: [video: FF.Graph.input(0, :video)]),
        outputs: [Command.output("out.mp4", :preview)]
      )

    assert_raise ArgumentError, "command graph has no output :preview", fn ->
      FF.to_argv(command)
    end
  end

  test "builds argv with named command inputs" do
    src = Command.input("input.mp4")
    logo = Command.input("logo.png")

    command =
      FF.command(
        inputs: [src: src, logo: logo],
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
    src = Command.input("input.mp4")

    command =
      FF.command(
        inputs: [src: src],
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

  test "input access accepts command input declarations" do
    src = Command.input("input.mp4")

    command =
      FF.command(
        inputs: [src: src],
        outputs: [
          Command.output("out.mka", src[audio: 1], acodec: :copy)
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

  test "supports access on command inputs" do
    src = Command.input("input.mp4")

    command =
      FF.command(
        inputs: [src: src],
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

  test "supports whole-input maps" do
    src = Command.input("input.mp4")

    command =
      FF.command(
        inputs: [src: src],
        outputs: [Command.output("out.mkv", src[:input], c: :copy)]
      )

    assert FF.to_argv(command) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-map",
             "0",
             "-c",
             "copy",
             "out.mkv"
           ]
  end

  test "rejects duplicate command input names" do
    assert_raise ArgumentError, "duplicate command input names: [:src]", fn ->
      FF.command(
        inputs: [
          src: Command.input("a.mp4"),
          src: Command.input("b.mp4")
        ],
        outputs: [Command.output("out.mp4", FF.Graph.input(0, :video), vcodec: :copy)]
      )
      |> FF.to_argv()
    end
  end

  test "rejects input labels" do
    assert_raise ArgumentError,
                 "input labels are not supported; name inputs in command inputs instead",
                 fn ->
                   Command.input("input.mp4", label: :src)
                 end
  end

  test "rejects non-keyword command inputs" do
    assert_raise ArgumentError,
                 "command inputs must be a keyword list of input/1 or input/2 values",
                 fn ->
                   FF.command(
                     inputs: [Command.input("input.mp4")],
                     outputs: [Command.output("out.mp4", FF.Graph.input(0, :video))]
                   )
                 end
  end

  test "supports string source shorthand in command inputs" do
    command =
      FF.command(
        inputs: [src: "input.mp4"],
        outputs: fn _graph, %{inputs: inputs} ->
          FF.output("out.mp4", video: inputs.src[:video], vcodec: :copy)
        end
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

  test "rejects missing named graph inputs" do
    command =
      FF.command(
        inputs: [src: Command.input("input.mp4")],
        graph: FF.graph(outputs: [video: FF.Graph.input(:missing, :video)]),
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
          src: Command.input("input.mp4", ss: "00:00:03", stream_loop: -1),
          logo: Command.input("logo.png", loop: 1, framerate: 1)
        ],
        outputs: [Command.output("out.mp4", FF.Graph.input(0, :video), vcodec: :copy)]
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

  test "encodes float command options as plain decimal strings" do
    command =
      FF.command(
        inputs: [src: Command.input("input.mp4")],
        outputs: [
          Command.output("out.mp4", FF.Graph.input(0, :video), t: 0.25, vcodec: :copy)
        ]
      )

    assert FF.to_argv(command) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-map",
             "0:v",
             "-t",
             "0.25",
             "-vcodec",
             "copy",
             "out.mp4"
           ]
  end

  test "builds argv from command, input, and output constructors" do
    video =
      FF.Graph.input(0, :video)
      |> Filter.scale(w: 1280, h: -1)
      |> Filter.drawtext(text: "Hello", x: FF.expr("w-tw-20"), y: 20)

    graph = FF.graph(outputs: [video: video])
    audio = FF.Graph.input(0, :audio)

    command =
      FF.command(
        global: [y: true, loglevel: :error],
        inputs: [src: Command.input("input.mp4")],
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
    graph = FF.graph(outputs: [raw: FF.Graph.input(0, :video)])

    command =
      FF.command()
      |> Command.input("input.mp4")
      |> Command.graph(graph)
      |> Command.output("out.mp4", graph[:raw], vcodec: :copy)

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

  test "renders a shell-safe command string for debugging" do
    video =
      FF.Graph.input(0, :video)
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
    graph = FF.graph(outputs: [video: FF.Graph.input(1, :video)])

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
    video = FF.Graph.input(0, :video)
    [master, preview] = Filter.split(video, outputs: 2)

    preview =
      preview
      |> Filter.fps(fps: 1)
      |> Filter.scale(w: 320, h: -1)

    graph = FF.graph(outputs: [master: master, preview: preview])
    audio = FF.Graph.input(0, :audio)

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

  test "rejects duplicated mappings for filter graph outputs" do
    graph = FF.graph(outputs: [video: FF.Graph.input(0, :video) |> Filter.scale(w: 320, h: -1)])

    command =
      FF.command(
        inputs: [src: Command.input("input.mp4")],
        graph: graph,
        outputs: [
          Command.output("a.mp4", :video, vcodec: :libx264),
          Command.output("b.mp4", :video, vcodec: :libx264)
        ]
      )

    assert_raise ArgumentError,
                 "graph output :video is mapped 2 times; complex filter outputs must be mapped exactly once",
                 fn ->
                   FF.to_argv(command)
                 end
  end

  test "rejects unmapped filter graph outputs" do
    graph =
      FF.graph(
        outputs: [
          master: FF.Graph.input(0, :video) |> Filter.scale(w: 1280, h: -1),
          preview: FF.Graph.input(0, :video) |> Filter.scale(w: 320, h: -1)
        ]
      )

    command =
      FF.command(
        inputs: [src: Command.input("input.mp4")],
        graph: graph,
        outputs: [Command.output("out.mp4", :master, vcodec: :libx264)]
      )

    assert_raise ArgumentError, "graph output :preview must be mapped exactly once", fn ->
      FF.to_argv(command)
    end
  end
end
