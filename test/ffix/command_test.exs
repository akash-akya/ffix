defmodule FFix.CommandTest do
  use ExUnit.Case, async: true

  alias FFix.{Command, Filter, Graph}

  test "graphs support access by named and positional outputs" do
    [master, preview] = Filter.split(Graph.input(0, :video), outputs: 2)
    graph = FFix.graph(outputs: [master: master, preview: preview])

    assert graph[:master] == Graph.export!(graph, :master)
    assert graph[0] == graph[:master]
    assert graph[1] == graph[:preview]
    assert graph[:missing] == nil
    assert graph[2] == nil
  end

  test "builds argv with named graph outputs and direct audio" do
    source = FFix.input("input.mp4")
    picture = FFix.video(source)

    graph =
      FFix.graph(
        outputs: [
          master: Filter.scale(picture, w: 1280, h: -1),
          preview: picture |> Filter.scale(w: 320, h: -1) |> Filter.fps(fps: 1)
        ]
      )

    command =
      FFix.command([
        FFix.output([graph[:master], FFix.select(source, {:audio, :all})], "master.mp4",
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
             "[0:v:0]scale=w=1280:h=-1[out0];\n[0:v:0]scale=w=320:h=-1[scale_1_0];\n[scale_1_0]fps=fps=1[out2];",
             "-map",
             "[out0]",
             "-map",
             "0:a",
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

  test "removed graph output shorthands require explicit references" do
    for shorthand <- [:preview, 0, 1] do
      assert_raise ArgumentError, fn -> FFix.output(shorthand, "out.mp4") end
    end
  end

  test "builds argv with independently declared inputs" do
    source = FFix.input("input.mp4")
    logo = FFix.input("logo.png")
    picture = Filter.overlay(FFix.video(source), FFix.video(logo), x: 20, y: 20)

    command =
      FFix.command(
        FFix.output([video: picture, audio: FFix.audio(source)], "out.mp4",
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

  test "selectors support indexed tracks, broad media, and whole-input maps" do
    source = FFix.input("input.mp4")

    for {selection, expected} <- [
          {FFix.audio(source, 1), "0:a:1"},
          {FFix.video(source), "0:v:0"},
          {FFix.select(source, {:video, :all}), "0:v"},
          {FFix.select(source, :all), "0"}
        ] do
      command = FFix.command(FFix.output(selection, "out.mkv", c: :copy))

      assert FFix.to_argv(command) == [
               "ffmpeg",
               "-i",
               "input.mp4",
               "-map",
               expected,
               "-c",
               "copy",
               "out.mkv"
             ]
    end

    refute function_exported?(FFix.Command.Input, :fetch, 2)
  end

  test "explicit input ordering uses declarations rather than named input bindings" do
    source = FFix.input("a.mp4")
    other = FFix.input("b.mp4")
    output = FFix.output(FFix.video(source), "out.mp4")
    assert_raise ArgumentError, fn -> FFix.command(output, inputs: [src: source, src: other]) end
  end

  test "rejects input labels" do
    assert_raise ArgumentError, ~r/input labels are not supported/, fn ->
      FFix.input("input.mp4", label: :src)
    end
  end

  test "callback command arities and constructor append overloads are removed" do
    assert Keyword.get_values(FFix.__info__(:functions), :command) == [1, 2]
    refute Keyword.has_key?(FFix.__info__(:macros), :__using__)
    refute Keyword.has_key?(Command.__info__(:functions), :input)
    refute Keyword.has_key?(Command.__info__(:functions), :output)
    source = FFix.input("input.mp4")

    assert_raise ArgumentError, fn ->
      FFix.command(source, fn _source -> flunk("must not run") end)
    end

    assert_raise ArgumentError, fn -> FFix.command(inputs: [source], outputs: []) end
  end

  test "ordinary functions can compose ordered list and map values" do
    source = FFix.input("input.mp4")
    music = FFix.input("music.mp3")

    scale = fn %{source: source} ->
      %{preview: Filter.scale(FFix.video(source), w: 320, h: -1)}
    end

    %{preview: preview} = scale.(%{source: source})
    streams = [preview: preview, music: FFix.audio(music)]
    command = FFix.command(FFix.output(streams, "out.mp4", vcodec: :libx264, acodec: :aac))

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-i",
             "music.mp3",
             "-filter_complex",
             "[0:v:0]scale=w=320:h=-1[out0];",
             "-map",
             "[out0]",
             "-map",
             "1:a:0",
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
      FFix.command(FFix.output(FFix.video(source), "out.mp4", vcodec: :copy),
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

  test "encodes float command options as plain decimal strings" do
    command =
      FFix.input("input.mp4")
      |> FFix.video()
      |> FFix.output("out.mp4", t: 0.25, vcodec: :copy)
      |> FFix.command()

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-map",
             "0:v:0",
             "-t",
             "0.25",
             "-vcodec",
             "copy",
             "out.mp4"
           ]
  end

  test "builds argv from explicit command, input, and output constructors" do
    source = FFix.input("input.mp4")

    video =
      FFix.video(source)
      |> Filter.scale(w: 1280, h: -1)
      |> Filter.drawtext(text: "Hello", x: "w-tw-20", y: 20)

    graph = FFix.graph(outputs: [video: video])

    command =
      Command.new(global: [y: :flag, loglevel: :error], graph: graph)
      |> Command.add_input(source)
      |> Command.add_output(
        FFix.output([hd(graph.exports), FFix.audio(source)], "out.mp4",
          vcodec: :libx264,
          acodec: :copy
        )
      )

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-y",
             "-loglevel",
             "error",
             "-i",
             "input.mp4",
             "-filter_complex",
             "[0:v:0]scale=w=1280:h=-1[scale_0];\n[scale_0]drawtext=text=Hello:x=w-tw-20:y=20[video];",
             "-map",
             "[video]",
             "-map",
             "0:a:0",
             "-vcodec",
             "libx264",
             "-acodec",
             "copy",
             "out.mp4"
           ]
  end

  test "maps graph exports backed by inputs as input stream refs" do
    source = FFix.input("input.mp4")
    graph = FFix.graph(outputs: [raw: FFix.video(source)])
    command = FFix.command(FFix.output(graph[:raw], "out.mp4", vcodec: :copy))

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-map",
             "0:v:0",
             "-vcodec",
             "copy",
             "out.mp4"
           ]
  end

  test "renders a shell-safe command string for debugging" do
    source = FFix.input("input file.mp4")

    video =
      FFix.video(source)
      |> Filter.scale(w: 1280, h: -1)
      |> Filter.drawtext(text: "hello world", x: "w-tw-20", y: 20)

    command = FFix.command(FFix.output(video, "out file.mp4", vcodec: :libx264))
    shell = FFix.to_shell_string(command)
    assert shell =~ "ffmpeg"
    assert shell =~ "-i 'input file.mp4'"
    assert shell =~ "-filter_complex '"
    assert shell =~ "'out file.mp4'"
  end

  test "rejects undeclared positional and named input refs" do
    for missing <- [1, :missing] do
      assert_raise ArgumentError, ~r/not declared|unbound/, fn ->
        FFix.command(FFix.output(Graph.input(missing, :video), "out.mp4"),
          inputs: [FFix.input("input.mp4")]
        )
      end
    end
  end

  test "builds argv for multiple outputs from one split graph" do
    source = FFix.input("input.mp4")
    [master, preview] = Filter.split(FFix.video(source), outputs: 2)
    preview = preview |> Filter.fps(fps: 1) |> Filter.scale(w: 320, h: -1)
    graph = FFix.graph(outputs: [master: master, preview: preview])

    command =
      FFix.command([
        FFix.output([graph[:master], FFix.audio(source)], "master.mp4",
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

  test "rejects duplicate consumers and unused outputs in a selected graph context" do
    source = FFix.input("input.mp4")
    video = Filter.scale(FFix.video(source), w: 320, h: -1)

    assert_raise ArgumentError, ~r/used 2 times|mapped 2 times/, fn ->
      FFix.command([FFix.output(video, "a.mp4"), FFix.output(video, "b.mp4")])
    end

    graph =
      FFix.graph(
        outputs: [master: video, preview: Filter.scale(FFix.video(source), w: 160, h: -1)]
      )

    assert_raise ArgumentError, ~r/unconnected filter output|must be mapped exactly once/, fn ->
      FFix.command(FFix.output(graph[:master], "out.mp4"))
    end
  end
end
