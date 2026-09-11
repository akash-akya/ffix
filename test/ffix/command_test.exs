defmodule FFix.CommandTest do
  use ExUnit.Case, async: true

  alias FFix.Command
  alias FFix.Filter

  test "graphs support access by named and positional outputs" do
    video = FFix.Graph.input(0, :video)
    [master, preview] = Filter.split(video, outputs: 2)
    graph = FFix.graph(outputs: [master: master, preview: preview])

    assert graph[:master] == FFix.Graph.export!(graph, :master)
    assert graph[0] == graph[:master]
    assert graph[1] == graph[:preview]
    assert graph[:missing] == nil
    assert graph[2] == nil
  end

  test "builds argv with inline graph output shorthands" do
    audio = FFix.Graph.input(0, :audio)

    command =
      FFix.command(
        inputs: [src: Command.input("input.mp4")],
        graph:
          FFix.graph(
            outputs: [
              master:
                FFix.Graph.input(0, :video)
                |> Filter.scale(w: 1280, h: -1),
              preview:
                FFix.Graph.input(0, :video)
                |> Filter.scale(w: 320, h: -1)
                |> Filter.fps(fps: 1)
            ]
          ),
        outputs: [
          Command.output([:master, audio], "master.mp4", vcodec: :libx264, acodec: :aac),
          Command.output(1, "thumb-%03d.jpg", f: :image2, vsync: 0)
        ]
      )

    assert FFix.to_argv(command) == [
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
    command = FFix.command(outputs: [Command.output(:preview, "out.mp4")])

    assert_raise ArgumentError, "output source :preview requires a command graph", fn ->
      FFix.to_argv(command)
    end
  end

  test "rejects missing inline graph output shorthands" do
    command =
      FFix.command(
        inputs: [src: Command.input("input.mp4")],
        graph: FFix.graph(outputs: [video: FFix.Graph.input(0, :video)]),
        outputs: [Command.output(:preview, "out.mp4")]
      )

    assert_raise ArgumentError, "command graph has no output :preview", fn ->
      FFix.to_argv(command)
    end
  end

  test "builds argv with named command inputs" do
    src = Command.input("input.mp4")
    logo = Command.input("logo.png")

    command =
      FFix.command(
        inputs: [src: src, logo: logo],
        graph:
          FFix.graph(
            outputs: [
              video:
                src[:video]
                |> Filter.overlay(logo[:video], x: 20, y: 20)
            ]
          ),
        outputs: [
          Command.output([:video, src[:audio]], "out.mp4", vcodec: :libx264, acodec: :aac)
        ]
      )

    assert FFix.to_argv(command) == [
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
      FFix.command(
        inputs: [src: src],
        outputs: [Command.output(src[audio: 1], "out.mka", acodec: :copy)]
      )

    assert FFix.to_argv(command) == [
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
      FFix.command(
        inputs: [src: src],
        outputs: [
          Command.output(src[audio: 1], "out.mka", acodec: :copy)
        ]
      )

    assert FFix.to_argv(command) == [
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
      FFix.command(
        inputs: [src: src],
        outputs: [Command.output(src[:video], "out.mp4", vcodec: :copy)]
      )

    assert FFix.to_argv(command) == [
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
      FFix.command(
        inputs: [src: src],
        outputs: [Command.output(src[:input], "out.mkv", c: :copy)]
      )

    assert FFix.to_argv(command) == [
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
      FFix.command(
        inputs: [
          src: Command.input("a.mp4"),
          src: Command.input("b.mp4")
        ],
        outputs: [Command.output(FFix.Graph.input(0, :video), "out.mp4", vcodec: :copy)]
      )
      |> FFix.to_argv()
    end
  end

  test "rejects input labels" do
    assert_raise ArgumentError,
                 "input labels are not supported; name inputs in command inputs instead",
                 fn ->
                   Command.input("input.mp4", label: :src)
                 end
  end

  test "command/3 preserves list input shape" do
    command =
      FFix.command(
        ["input.mp4", "music.mp3"],
        fn [src, _music] ->
          src[:video] |> Filter.scale(w: 320, h: -1)
        end,
        fn scaled, [_src, music] ->
          FFix.output([scaled, music[:audio]], "out.mp4",
            vcodec: :libx264,
            acodec: :aac
          )
        end
      )

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-i",
             "music.mp3",
             "-filter_complex",
             "[0:v]scale=w=320:h=-1[out0];",
             "-map",
             "[out0]",
             "-map",
             "1:a",
             "-vcodec",
             "libx264",
             "-acodec",
             "aac",
             "out.mp4"
           ]
  end

  test "command/3 preserves keyword input shape" do
    command =
      FFix.command(
        [src: "input.mp4"],
        fn inputs ->
          inputs[:src][:video]
        end,
        fn video, inputs ->
          FFix.output([video, inputs[:src][:audio]], "out.mp4", vcodec: :copy)
        end
      )

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-map",
             "0:v",
             "-map",
             "0:a",
             "-vcodec",
             "copy",
             "out.mp4"
           ]
  end

  test "command/4 accepts command options at the end" do
    command =
      FFix.command(
        "input.mp4",
        fn src ->
          src[:video]
        end,
        fn video ->
          FFix.output([video], "out.mp4", vcodec: :copy)
        end,
        global: [y: true, loglevel: :error]
      )

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-y",
             "-loglevel",
             "error",
             "-i",
             "input.mp4",
             "-map",
             "0:v",
             "-vcodec",
             "copy",
             "out.mp4"
           ]
  end

  test "command/4 rejects old command shape keys in options" do
    error =
      assert_raise ArgumentError, fn ->
        FFix.command(
          "input.mp4",
          fn src -> src[:video] end,
          fn video -> FFix.output([video], "out.mp4", vcodec: :copy) end,
          inputs: [],
          graph: nil,
          outputs: []
        )
      end

    assert Exception.message(error) ==
             "command/4 options only support :global; pass inputs, graph, and outputs as positional arguments, got: [:inputs, :graph, :outputs]"
  end

  test "command/3 preserves graph list shape" do
    command =
      FFix.command(
        "input.mp4",
        fn src ->
          [
            src[:video] |> Filter.scale(w: 320, h: -1),
            src[:audio]
          ]
        end,
        fn [video, audio] ->
          FFix.output([video, audio], "out.mkv",
            vcodec: :libx264,
            acodec: :aac
          )
        end
      )

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-filter_complex",
             "[0:v]scale=w=320:h=-1[out0];",
             "-map",
             "[out0]",
             "-map",
             "0:a",
             "-vcodec",
             "libx264",
             "-acodec",
             "aac",
             "out.mkv"
           ]
  end

  test "command/3 preserves map input and graph shapes" do
    command =
      FFix.command(
        %{src: "input.mp4"},
        fn %{src: src} ->
          %{preview: src[:video] |> Filter.scale(w: 320, h: -1)}
        end,
        fn %{preview: preview}, %{src: src} ->
          FFix.output([preview, src[:audio]], "preview.mp4",
            vcodec: :libx264,
            acodec: :aac
          )
        end
      )

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-filter_complex",
             "[0:v]scale=w=320:h=-1[preview];",
             "-map",
             "[preview]",
             "-map",
             "0:a",
             "-vcodec",
             "libx264",
             "-acodec",
             "aac",
             "preview.mp4"
           ]
  end

  test "rejects missing named graph inputs" do
    command =
      FFix.command(
        inputs: [src: Command.input("input.mp4")],
        graph: FFix.graph(outputs: [video: FFix.Graph.input(:missing, :video)]),
        outputs: [Command.output(:video, "out.mp4")]
      )

    assert_raise ArgumentError, ~s(input "missing" is not declared in the command), fn ->
      FFix.to_argv(command)
    end
  end

  test "builds argv with input options" do
    command =
      FFix.command(
        global: [y: true],
        inputs: [
          src: Command.input("input.mp4", ss: "00:00:03", stream_loop: -1),
          logo: Command.input("logo.png", loop: 1, framerate: 1)
        ],
        outputs: [Command.output(FFix.Graph.input(0, :video), "out.mp4", vcodec: :copy)]
      )

    assert FFix.to_argv(command) == [
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
      FFix.command(
        inputs: [src: Command.input("input.mp4")],
        outputs: [
          Command.output(FFix.Graph.input(0, :video), "out.mp4", t: 0.25, vcodec: :copy)
        ]
      )

    assert FFix.to_argv(command) == [
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
      FFix.Graph.input(0, :video)
      |> Filter.scale(w: 1280, h: -1)
      |> Filter.drawtext(text: "Hello", x: FFix.expr("w-tw-20"), y: 20)

    graph = FFix.graph(outputs: [video: video])
    audio = FFix.Graph.input(0, :audio)

    command =
      FFix.command(
        global: [y: true, loglevel: :error],
        inputs: [src: Command.input("input.mp4")],
        graph: graph,
        outputs: [
          Command.output([graph[:video], audio], "out.mp4", vcodec: :libx264, acodec: :copy)
        ]
      )

    assert FFix.to_argv(command) == [
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
    graph = FFix.graph(outputs: [raw: FFix.Graph.input(0, :video)])

    command =
      FFix.command()
      |> Command.input("input.mp4")
      |> Command.graph(graph)
      |> Command.output(graph[:raw], "out.mp4", vcodec: :copy)

    assert FFix.to_argv(command) == [
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
      FFix.Graph.input(0, :video)
      |> Filter.scale(w: 1280, h: -1)
      |> Filter.drawtext(text: "hello world", x: FFix.expr("w-tw-20"), y: 20)

    graph = FFix.graph(outputs: [video: video])

    command =
      FFix.command()
      |> Command.input("input file.mp4")
      |> Command.graph(graph)
      |> Command.output(graph[:video], "out file.mp4", vcodec: :libx264)

    shell = FFix.to_shell_string(command)

    assert shell =~ "ffmpeg"
    assert shell =~ "-i 'input file.mp4'"
    assert shell =~ "-filter_complex '"
    assert shell =~ "'out file.mp4'"
  end

  test "rejects input refs that do not exist in the command" do
    graph = FFix.graph(outputs: [video: FFix.Graph.input(1, :video)])

    command =
      FFix.command()
      |> Command.input("input.mp4")
      |> Command.graph(graph)
      |> Command.output(graph[:video], "out.mp4", vcodec: :libx264)

    assert_raise ArgumentError, "input 1 is not declared in the command", fn ->
      FFix.to_argv(command)
    end
  end

  test "builds argv for multiple outputs from one graph" do
    video = FFix.Graph.input(0, :video)
    [master, preview] = Filter.split(video, outputs: 2)

    preview =
      preview
      |> Filter.fps(fps: 1)
      |> Filter.scale(w: 320, h: -1)

    graph = FFix.graph(outputs: [master: master, preview: preview])
    audio = FFix.Graph.input(0, :audio)

    command =
      FFix.command()
      |> Command.input("input.mp4")
      |> Command.graph(graph)
      |> Command.output([graph[:master], audio], "master.mp4", vcodec: :libx264, acodec: :aac)
      |> Command.output(graph[:preview], "thumb-%03d.jpg", f: :image2, vsync: 0)

    assert FFix.to_argv(command) == [
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
    graph =
      FFix.graph(outputs: [video: FFix.Graph.input(0, :video) |> Filter.scale(w: 320, h: -1)])

    command =
      FFix.command(
        inputs: [src: Command.input("input.mp4")],
        graph: graph,
        outputs: [
          Command.output(:video, "a.mp4", vcodec: :libx264),
          Command.output(:video, "b.mp4", vcodec: :libx264)
        ]
      )

    assert_raise ArgumentError,
                 "graph output :video is mapped 2 times; complex filter outputs must be mapped exactly once",
                 fn ->
                   FFix.to_argv(command)
                 end
  end

  test "rejects unmapped filter graph outputs" do
    graph =
      FFix.graph(
        outputs: [
          master: FFix.Graph.input(0, :video) |> Filter.scale(w: 1280, h: -1),
          preview: FFix.Graph.input(0, :video) |> Filter.scale(w: 320, h: -1)
        ]
      )

    command =
      FFix.command(
        inputs: [src: Command.input("input.mp4")],
        graph: graph,
        outputs: [Command.output(:master, "out.mp4", vcodec: :libx264)]
      )

    assert_raise ArgumentError, "graph output :preview must be mapped exactly once", fn ->
      FFix.to_argv(command)
    end
  end
end
