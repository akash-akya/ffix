defmodule FFix.CommandValidationTest do
  use ExUnit.Case, async: true

  alias FFix.{Command, Decoder, Demuxer, Encoder, Filter, Graph, Muxer}

  test "decoder namespaces cannot silently overlap" do
    input =
      FFix.input("in.mp4")
      |> Decoder.decode("rawvideo", {:index, 0}, threads: 1)
      |> Decoder.decode("mpeg4", {:video, 0}, skip_frame: "nokey")

    output = FFix.output(FFix.video(input), "out.mp4")
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

  test "either decoder namespace remains independently usable" do
    for selectors <- [[{:index, 0}, {:index, 1}], [{:video, 0}, {:audio, 0}]] do
      [picture_selector, sound_selector] = selectors
      input = FFix.input("in.mp4")
      input = Decoder.decode(input, "mpeg4", picture_selector, threads: 1)
      input = Decoder.decode(input, "aac", sound_selector, threads: 2)
      output = FFix.output(FFix.video(input), "out.mp4")
      argv = FFix.command(output) |> FFix.to_argv()
      assert "mpeg4" in argv
      assert "aac" in argv
    end
  end

  test "canonical commands reject changed snapshots in direct and graph references" do
    original = FFix.input("in.mp4")
    selected = FFix.video(original)
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

    uncaptured = FFix.output(Graph.input(0, :video), "out.mp4")
    assert "-ss" in FFix.to_argv(Command.new(inputs: [changed], outputs: [uncaptured]))
  end

  test "canonical commands cannot discard context from a direct graph export" do
    input = FFix.input("in.mp4")
    selected = FFix.video(input)
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

  test "input-only graph context is collected before direct command lowering" do
    picture = FFix.input("picture.mp4")
    sound = FFix.input("sound.wav")
    graph = FFix.graph(outputs: [main: FFix.video(picture), other: FFix.audio(sound)])
    command = graph[:main] |> FFix.output("out.mp4") |> FFix.command()
    assert command.graph == nil
    assert command.inputs == [picture, sound]

    [output] = command.outputs
    [mapping] = output.mappings
    assert mapping.source.context == nil

    refute "-filter_complex" in FFix.to_argv(command)
  end

  test "malformed sources and targets fail at construction and on hand-built structs" do
    for invalid <- [%{}, nil, :bad, "", <<0>>, pipe: -1, url: 4] do
      assert_raise ArgumentError, ~r/invalid input/, fn -> FFix.input(invalid) end
      source = FFix.input("in.mp4")

      assert_raise ArgumentError, ~r/invalid output/, fn ->
        FFix.output(FFix.video(source), invalid)
      end

      output = FFix.output(FFix.video(source), "out.mp4")
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
    video = FFix.video(source)

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

    input = source
    command = FFix.command(FFix.output(FFix.video(input), "out.mp4"))
    assert "-future_option" in FFix.to_argv(command)
    assert Enum.count(FFix.to_argv(command), &(&1 == "-metadata")) == 2
  end

  test "known media mismatches are caught, but generic names still bypass metadata" do
    source = FFix.input("in.mp4")
    video = FFix.video(source)
    audio = FFix.audio(source)
    assert_raise ArgumentError, ~r/expects audio/, fn -> Encoder.aac(video) end
    assert_raise ArgumentError, ~r/expects video/, fn -> Encoder.libx264(audio) end
    assert_raise ArgumentError, ~r/expects video/, fn -> Filter.scale(audio) end
    assert_raise ArgumentError, ~r/expects video/, fn -> Graph.parse!("[0:a]scale[out]") end
    assert %Command.Mapping{} = Encoder.encode(video, "aac")
    assert %FFix.Graph.StreamRef{} = Filter.filter(audio, "scale", [:video])
  end

  test "input declaration identity is not filename equality, and mapping/output occurrences are not deduplicated" do
    first = FFix.input("same.mp4")
    second = FFix.input("same.mp4")
    refute first.id == second.id
    mapping = Encoder.encode(FFix.video(first), "mpeg4")

    output =
      FFix.output([main: mapping], "out.mp4",
        metadata: fn streams -> "title=#{streams.main.index}" end
      )

    command = FFix.command([output, output], inputs: [first, second])
    argv = FFix.to_argv(command)
    assert Enum.count(argv, &(&1 == "-i")) == 2
    assert Enum.count(argv, &(&1 == "-map")) == 2
    assert Enum.count(argv, &(&1 == "-c:0")) == 2
    assert Enum.count(argv, &(&1 == "title=0")) == 2
  end

  test "output-first materialization agrees with explicit low-level canonical exports" do
    input = FFix.input("in.mp4")
    picture = FFix.Filter.scale(FFix.video(input), w: 16, h: 16)
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
    changed = %{picture | plan: %{picture.plan | args: [w: 32, h: 32]}}

    assert_raise ArgumentError, ~r/conflicting definitions/, fn ->
      FFix.command([output, FFix.output(changed, "other.mp4")])
    end

    assert_raise ArgumentError, ~r/used 2 times/, fn -> FFix.command([output, output]) end
  end

  test "appending an input declaration preserves its configuration and identity" do
    input = FFix.Demuxer.mov("in.mp4", input_options: [ss: 2])
    command = Command.new() |> Command.add_input(input)
    assert command.inputs == [input]
    command = Command.add_output(command, FFix.output(FFix.video(input), "out.mp4"))
    assert "0:v:0" in FFix.to_argv(command)
  end

  test "deferred raw values receive the same structural validation exactly once" do
    parent = self()
    source = FFix.input("in.mp4")

    command =
      FFix.command(
        FFix.output(FFix.video(source), "out.mp4",
          metadata: fn _streams ->
            send(parent, :resolved)
            "bad\0text"
          end
        )
      )

    FFix.validate!(command)
    refute_received :resolved

    assert_raise ArgumentError, "CLI option values cannot contain NUL", fn ->
      FFix.to_argv(command)
    end

    assert_received :resolved
    refute_received :resolved
  end

  test "conflict aliases are canonicalized in both directions" do
    for {structured, raw} <- [ab: :b, b: :ab, vb: :b, b: :vb] do
      source = FFix.input("in.mp4")
      mapping = Encoder.encode(FFix.audio(source), "vendor", [{structured, "64k"}])

      assert_raise ArgumentError, ~r/cannot be combined/, fn ->
        FFix.command(FFix.output(mapping, "out.mkv", [{raw, "128k"}]))
      end
    end
  end
end
