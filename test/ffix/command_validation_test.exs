defmodule FFix.CommandValidationTest do
  use ExUnit.Case, async: true

  alias FFix.{Command, Decoder, Demuxer, Encoder, Filter, Graph, Muxer}

  test "decoder namespaces cannot silently overlap" do
    input =
      FFix.input("in.mp4")
      |> Decoder.decode("rawvideo", {:index, 0}, threads: 1)
      |> Decoder.decode("mpeg4", {:video, 0}, skip_frame: "nokey")

    output = FFix.output(FFix.video(input, 0), "out.mp4")
    command = Command.new(inputs: [input], outputs: [output])

    assert_raise ArgumentError,
                 ~r/cannot mix absolute and media-relative decoder selectors/,
                 fn ->
                   FFix.validate!(command)
                 end

    assert_raise ArgumentError,
                 ~r/cannot mix absolute and media-relative decoder selectors/,
                 fn ->
                   FFix.input("in.mp4", decoders: input.decoders)
                 end
  end

  test "absolute decoder selectors retain their input-local indexes" do
    input =
      FFix.input("in.mp4")
      |> Decoder.decode("mpeg4", {:index, 3}, threads: 1)
      |> Decoder.decode("aac", {:index, 1}, threads: 2)

    command = input |> FFix.video(0) |> FFix.output("out.mp4") |> FFix.command()

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-c:1",
             "aac",
             "-threads:1",
             "2",
             "-c:3",
             "mpeg4",
             "-threads:3",
             "1",
             "-i",
             "in.mp4",
             "-map",
             "0:v:0",
             "out.mp4"
           ]
  end

  test "canonical commands reject changed snapshots in direct and graph references" do
    original = FFix.input("in.mp4")
    selected = FFix.video(original, 0)
    changed = %{original | options: [ss: 10]}
    direct = FFix.output(selected, "out.mp4")
    graph = FFix.graph(output: Filter.hflip(selected))
    filtered = FFix.output(hd(graph.exports), "out.mp4")

    for command <- [
          Command.new(inputs: [changed], outputs: [direct]),
          Command.new(inputs: [changed], graph: graph, outputs: [filtered])
        ] do
      assert_raise ArgumentError, ~r/conflicting input snapshots/, fn ->
        FFix.to_argv(command)
      end
    end

    assert FFix.validate!(Command.new(inputs: [original], outputs: [direct]))
    assert FFix.validate!(Command.new(inputs: [original], graph: graph, outputs: [filtered]))

    uncaptured = FFix.output(Graph.input(0, {:video, 0}), "out.mp4")
    assert "-ss" in FFix.to_argv(Command.new(inputs: [changed], outputs: [uncaptured]))
  end

  test "canonical commands cannot discard a direct reference's other graph branches" do
    input = FFix.input("in.mp4")
    selected = FFix.video(input, 0)
    sink = selected |> Filter.hflip() |> Filter.nullsink()
    graph = FFix.graph(outputs: [main: selected], terminals: [sink])
    output = FFix.output(graph[:main], "out.mp4")

    assert_raise ArgumentError, ~r/graph references require FFix.command/, fn ->
      FFix.to_argv(Command.new(inputs: [input], outputs: [output]))
    end

    command = FFix.command(output)
    assert length(command.graph.terminals) == 1
    assert Enum.any?(FFix.to_argv(command), &String.contains?(&1, "nullsink"))

    canonical = FFix.output(hd(graph.exports), "out.mp4")
    assert FFix.validate!(Command.new(inputs: [input], graph: graph, outputs: [canonical]))
  end

  test "selecting an input-only graph export retains its other input declarations" do
    picture = FFix.input("picture.mp4")
    sound = FFix.input("sound.wav")
    graph = FFix.graph(outputs: [main: FFix.video(picture, 0), other: FFix.audio(sound, 0)])
    command = graph[:main] |> FFix.output("out.mp4") |> FFix.command()
    assert command.inputs == [picture, sound]

    refute "-filter_complex" in FFix.to_argv(command)
  end

  test "graph settings require filters in both command construction styles" do
    input = FFix.input("in.mp4")
    stream = FFix.video(input, 0)
    settings = [sws_flags: "bilinear"]

    for source <- [stream, FFix.video(input, :all)] do
      output = FFix.output(source, "out.mp4")

      assert_raise ArgumentError, ~r/graph settings require filter nodes/, fn ->
        FFix.command(output, settings: settings)
      end

      graphs = [
        %Graph{id: make_ref(), settings: settings},
        FFix.graph(output: stream, settings: settings)
      ]

      for graph <- graphs do
        command = Command.new(inputs: [input], graph: graph, outputs: [output])

        assert_raise ArgumentError, ~r/graph settings require filter nodes/, fn ->
          Command.validate!(command)
        end

        assert_raise ArgumentError, ~r/graph settings require filter nodes/, fn ->
          FFix.to_argv(command)
        end
      end
    end
  end

  test "malformed sources and targets fail at construction and on hand-built structs" do
    for invalid <- [%{}, nil, :bad, "", <<0>>, pipe: -1, url: 4] do
      assert_raise ArgumentError, ~r/invalid input/, fn -> FFix.input(invalid) end
      source = FFix.input("in.mp4")

      assert_raise ArgumentError, ~r/invalid output/, fn ->
        FFix.output(FFix.video(source, 0), invalid)
      end

      output = FFix.output(FFix.video(source, 0), "out.mp4")
      bad_input = %{source | source: invalid}
      command = Command.new(inputs: [bad_input], outputs: [output])
      assert_raise ArgumentError, ~r/invalid input/, fn -> FFix.validate!(command) end
      command = Command.new(inputs: [source], outputs: [%{output | target: invalid}])
      assert_raise ArgumentError, ~r/invalid output/, fn -> FFix.validate!(command) end
    end

    assert_raise ArgumentError, ~r/invalid input/, fn -> FFix.input("in.mp4") |> Demuxer.mov() end
  end

  test "duplicate configuration controls cannot silently disappear" do
    source = FFix.input("in.mp4")
    video = FFix.video(source, 0)

    for options <- [
          [demuxer: Demuxer.new("mov"), demuxer: Demuxer.new("matroska")],
          [decoders: %{}, decoders: %{}]
        ] do
      assert_raise ArgumentError, ~r/duplicate option/, fn -> FFix.input("in.mp4", options) end
    end

    assert_raise ArgumentError, ~r/duplicate option/, fn ->
      FFix.output(video, "out.mp4", muxer: Muxer.new("mp4"), muxer: Muxer.new("matroska"))
    end

    for constructor <- [&Encoder.new/2, &Decoder.new/2, &Demuxer.new/2, &Muxer.new/2] do
      assert_raise ArgumentError, ~r/duplicate component option/, fn ->
        constructor.("vendor", [{:custom, 1}, {"custom", 2}])
      end
    end
  end

  test "raw CLI shapes are validated without restricting unknown FFmpeg names or repeats" do
    for invalid <- [[{"-c", "copy"}], [{"bad key", 1}], [{"", 1}], [custom: %{}], [custom: <<0>>]] do
      assert_raise ArgumentError, fn -> FFix.input("in.mp4", invalid) end
    end

    source =
      FFix.input("in.mp4", [{"future_option", "value"}, metadata: "first", metadata: "second"])

    command = FFix.command(FFix.output(FFix.video(source, 0), "out.mp4"))

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-future_option",
             "value",
             "-metadata",
             "first",
             "-metadata",
             "second",
             "-i",
             "in.mp4",
             "-map",
             "0:v:0",
             "out.mp4"
           ]
  end

  test "known media mismatches are caught, but generic names still bypass metadata" do
    source = FFix.input("in.mp4")
    video = FFix.video(source, 0)
    audio = FFix.audio(source, 0)
    assert_raise ArgumentError, ~r/expects audio/, fn -> Encoder.aac(video) end
    assert_raise ArgumentError, ~r/expects video/, fn -> Encoder.libx264(audio) end
    assert_raise ArgumentError, ~r/expects video/, fn -> Filter.scale(audio) end
    assert_raise ArgumentError, ~r/expects video/, fn -> Graph.parse!("[0:a]scale[out]") end
    assert %Command.Mapping{} = Encoder.encode(video, "aac")
    assert %FFix.Graph.StreamRef{} = Filter.filter(audio, "scale", [:video])
  end

  test "separate input declarations open the same filename independently" do
    first = FFix.input("same.mp4")
    second = FFix.input("same.mp4")
    output = FFix.output([FFix.video(first, 0), FFix.video(second, 0)], "out.mp4")
    command = FFix.command(output)
    assert command.inputs == [first, second]

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-i",
             "same.mp4",
             "-i",
             "same.mp4",
             "-map",
             "0:v:0",
             "-map",
             "1:v:0",
             "out.mp4"
           ]
  end

  test "output-first materialization agrees with explicit low-level canonical exports" do
    input = FFix.input("in.mp4")
    picture = FFix.Filter.scale(FFix.video(input, 0), w: 16, h: 16)
    output = FFix.output(picture, "out.mp4")
    expected = FFix.command(output) |> FFix.to_argv()
    graph = FFix.graph(output: picture)

    explicit =
      Command.new(
        inputs: [input],
        graph: graph,
        outputs: [FFix.output(hd(graph.exports), "out.mp4")]
      )

    assert FFix.to_argv(explicit) == expected
  end

  test "conflict aliases are canonicalized in both directions" do
    for {structured, raw} <- [ab: :b, b: :ab, vb: :b, b: :vb] do
      source = FFix.input("in.mp4")
      mapping = Encoder.encode(FFix.audio(source, 0), "vendor", [{structured, "64k"}])

      assert_raise ArgumentError, ~r/cannot be combined/, fn ->
        FFix.command(FFix.output(mapping, "out.mkv", [{raw, "128k"}]))
      end
    end
  end
end
