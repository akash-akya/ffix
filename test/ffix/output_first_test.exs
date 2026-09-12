defmodule FFix.OutputFirstTest do
  use ExUnit.Case, async: true

  alias FFix.{Command, Decoder, Filter, Graph}
  alias FFix.Command.Input

  test "direct mappings infer declaration order and do not emit an empty graph" do
    first = FFix.input("same.mp4")
    second = FFix.input("same.mp4", ss: 2)

    command =
      [FFix.audio(second, 0), FFix.video(first, 0), FFix.video(second, 0)]
      |> FFix.output("out.mkv")
      |> FFix.command()

    assert command.inputs == [second, first]

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-ss",
             "2",
             "-i",
             "same.mp4",
             "-i",
             "same.mp4",
             "-map",
             "0:a:0",
             "-map",
             "1:v:0",
             "-map",
             "0:v:0",
             "out.mkv"
           ]
  end

  test "explicit inputs retain order, include metadata-only inputs, and deduplicate identity" do
    first = FFix.input("first.mp4")
    second = FFix.input("second.mp4")
    metadata = FFix.input("metadata.txt")
    output = FFix.output(FFix.video(second, 0), "out.mp4")
    command = FFix.command(output, inputs: [first, metadata, second, second])

    assert command.inputs == [first, metadata, second]
    assert Enum.take(FFix.to_argv(command), -3) == ["-map", "2:v:0", "out.mp4"]
  end

  test "captured configurations must agree with each other and explicit declarations" do
    original = FFix.input("in.mp4")
    configured = Decoder.decode(original, "h264", {:video, 0}, threads: 2)
    old_stream = FFix.video(original, 0)
    new_stream = FFix.audio(configured, 0)

    assert_raise ArgumentError, ~r/conflicting input snapshots/, fn ->
      FFix.command(FFix.output([old_stream, new_stream], "out.mkv"))
    end

    assert_raise ArgumentError, ~r/conflicting input snapshots/, fn ->
      FFix.command(FFix.output(old_stream, "out.mkv"), inputs: [configured])
    end

    assert_raise ArgumentError, ~r/conflicting input snapshots/, fn ->
      FFix.command(FFix.output(new_stream, "out.mkv"), inputs: [original, configured])
    end

    assert_raise ArgumentError, ~r/missing from explicit/, fn ->
      FFix.command(FFix.output(new_stream, "out.mkv"), inputs: [])
    end
  end

  test "unbound positional refs require explicit declarations" do
    output = FFix.output(Graph.input(0, {:video, 0}), "out.mp4")
    assert_raise ArgumentError, ~r/unbound input reference/, fn -> FFix.command(output) end
    command = FFix.command(output, inputs: [FFix.input("in.mp4")])
    assert Enum.take(FFix.to_argv(command), -3) == ["-map", "0:v:0", "out.mp4"]

    assert_raise ArgumentError, ~r/not declared/, fn ->
      FFix.command(FFix.output(Graph.input(2, :video), "out.mp4"),
        inputs: [FFix.input("in.mp4")]
      )
    end

    assert_raise ArgumentError, ~r/unbound input reference/, fn ->
      FFix.command(FFix.output(Graph.input(:main, :video), "out.mp4"))
    end
  end

  test "selectors preserve FFmpeg suffixes and mapping order" do
    input = FFix.input("in.mkv")

    streams = [
      FFix.select(input, :all),
      FFix.video(input, :all),
      FFix.audio(input, 2),
      FFix.subtitle(input, 1),
      Input.select_media(input, :data, 0),
      Input.select_media(input, :attachment, 0),
      FFix.select(input, 4),
      FFix.select(input, "s?")
    ]

    argv = streams |> FFix.output("out.mkv") |> FFix.command() |> FFix.to_argv()

    assert argv == [
             "ffmpeg",
             "-i",
             "in.mkv",
             "-map",
             "0",
             "-map",
             "0:v",
             "-map",
             "0:a:2",
             "-map",
             "0:s:1",
             "-map",
             "0:d:0",
             "-map",
             "0:t:0",
             "-map",
             "0:4",
             "-map",
             "0:s?",
             "out.mkv"
           ]
  end

  test "reconfiguring a decoder replaces that selector without retaining old options" do
    input =
      FFix.input("in.mkv")
      |> Decoder.decode("old", {:subtitle, 0}, threads: 2)
      |> Decoder.decode("new", {:subtitle, 0}, custom: "replacement")

    command = input |> FFix.subtitle(0) |> FFix.output("out.mkv") |> FFix.command()

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-c:s:0",
             "new",
             "-custom:s:0",
             "replacement",
             "-i",
             "in.mkv",
             "-map",
             "0:s:0",
             "out.mkv"
           ]
  end

  test "raw switches and booleans have distinct serialization" do
    source = FFix.input("in.mp4", enabled: true) |> FFix.video(0)
    command = FFix.command(FFix.output(source, "out.mp4", enabled: false), global: [y: :flag])

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-y",
             "-enabled",
             "1",
             "-i",
             "in.mp4",
             "-map",
             "0:v:0",
             "-enabled",
             "0",
             "out.mp4"
           ]

    assert_raise ArgumentError, ~r/nil is not a CLI option value/, fn ->
      FFix.input("in.mp4", y: nil)
    end

    assert_raise ArgumentError, ~r/nil is not a CLI option value/, fn ->
      FFix.output(source, "out.mp4", y: nil)
    end
  end

  test "filtered sources infer dependencies and must be consumed exactly once" do
    source = FFix.input("in.mp4") |> FFix.video(0)
    filtered = Filter.hflip(source)
    command = FFix.command(FFix.output(filtered, "out.mp4"))
    assert "-filter_complex" in FFix.to_argv(command)
    assert [%Input{source: "in.mp4"}] = command.inputs

    assert_raise ArgumentError, ~r/is used 2 times/, fn ->
      FFix.command([FFix.output(filtered, "one.mp4"), FFix.output(filtered, "two.mp4")])
    end

    assert_raise ArgumentError, ~r/cannot copy a filtered source/, fn ->
      filtered |> FFix.stream_copy() |> FFix.output("out.mp4") |> FFix.command()
    end
  end

  test "terminal dependencies and graph settings survive command construction" do
    source = FFix.input("main.mp4") |> FFix.video(0)
    terminal = FFix.input("sink.mp4") |> FFix.audio(0) |> Filter.anullsink()

    command =
      FFix.command(FFix.output(source, "out.mp4"),
        terminals: [terminal],
        settings: [sws_flags: "bicubic"]
      )

    assert Enum.map(command.inputs, & &1.source) == ["main.mp4", "sink.mp4"]
    assert command.graph.settings == [sws_flags: "bicubic"]
    assert "sws_flags=bicubic;\n[1:a:0]anullsink;" in FFix.to_argv(command)

    assert_raise ArgumentError, ~r/settings require filter nodes/, fn ->
      FFix.command(FFix.output(source, "out.mp4"), settings: [sws_flags: "bicubic"])
    end
  end

  test "bare canonical exports require an explicit graph command" do
    input = FFix.input("in.mp4")
    graph = FFix.graph(output: FFix.video(input, 0))
    output = FFix.output(hd(graph.exports), "out.mp4")

    assert_raise ArgumentError, ~r/bare graph Export/, fn -> FFix.command(output) end

    command = Command.new(inputs: [input], graph: graph, outputs: [output])
    assert FFix.to_argv(command) == ["ffmpeg", "-i", "in.mp4", "-map", "0:v:0", "out.mp4"]
  end

  test "command controls require unique, supported keyword keys" do
    output = FFix.input("in.mp4") |> FFix.video(0) |> FFix.output("out.mp4")

    Enum.each([[{"global", []}], [global: [], global: []], [unknown: []]], fn options ->
      assert_raise ArgumentError, fn -> Command.new(options) end
      assert_raise ArgumentError, fn -> FFix.command(output, options) end
    end)
  end
end
