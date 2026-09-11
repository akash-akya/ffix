defmodule FFix.CommandValidationTest do
  use ExUnit.Case, async: true

  alias FFix.{Command, Decoder, Demuxer, Encoder, Filter, Graph, Muxer}

  test "malformed sources and targets fail at construction and on hand-built structs" do
    for invalid <- [%{}, nil, :bad, "", <<0>>, {:pipe, -1}, {:url, 4}] do
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

    assert_raise ArgumentError, ~r/invalid input/, fn ->
      FFix.input("in.mp4") |> Demuxer.mov()
    end
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
      FFix.input("in.mp4", [
        {"future_option", "value"},
        {:metadata, "first"},
        {:metadata, "second"}
      ])

    command = FFix.command(source, fn input -> FFix.output(FFix.video(input), "out.mp4") end)
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

    command = FFix.command([first, second], fn _inputs -> [output, output] end)
    argv = FFix.to_argv(command)
    assert Enum.count(argv, &(&1 == "-i")) == 2
    assert Enum.count(argv, &(&1 == "-map")) == 2
    assert Enum.count(argv, &(&1 == "-c:0")) == 2
    assert Enum.count(argv, &(&1 == "title=0")) == 2
  end

  test "prebuilt filtered outputs compile consistently through each constructor" do
    input = FFix.input("in.mp4")
    picture = FFix.Filter.scale(FFix.video(input), w: 16, h: 16)
    output = FFix.output(picture, "out.mp4")
    expected = FFix.command(input, fn _ -> output end) |> FFix.to_argv()

    for constructor <- [&Command.new/1, &FFix.command/1] do
      assert constructor.(inputs: [input], outputs: [output]) |> FFix.to_argv() == expected
    end

    changed = %{picture | plan: %{picture.plan | args: [w: 32, h: 32]}}

    assert_raise ArgumentError, ~r/conflicting definitions/, fn ->
      Command.new(inputs: [input], outputs: [output, FFix.output(changed, "other.mp4")])
    end

    assert_raise ArgumentError, ~r/used 2 times/, fn ->
      Command.new(inputs: [input], outputs: [output, output]) |> FFix.to_argv()
    end
  end

  test "appending an input declaration preserves its configuration and identity" do
    input = FFix.Demuxer.mov("in.mp4", input_options: [ss: 2])
    command = Command.new() |> Command.input(input)
    assert command.inputs == [input]
    command = Command.output(command, FFix.video(input), "out.mp4")
    assert "0:v:0" in FFix.to_argv(command)
  end

  test "deferred raw values receive the same structural validation exactly once" do
    parent = self()

    command =
      FFix.command("in.mp4", fn source ->
        FFix.output(FFix.video(source), "out.mp4",
          metadata: fn _streams ->
            send(parent, :resolved)
            "bad\0text"
          end
        )
      end)

    FFix.validate!(command)
    refute_received :resolved

    assert_raise ArgumentError, "CLI option values cannot contain NUL", fn ->
      FFix.to_argv(command)
    end

    assert_received :resolved
    refute_received :resolved
  end

  test "conflict aliases are canonicalized in both directions" do
    for {structured, raw} <- [{:ab, :b}, {:b, :ab}, {:vb, :b}, {:b, :vb}] do
      command =
        FFix.command("in.mp4", fn source ->
          mapping = Encoder.encode(FFix.audio(source), "vendor", [{structured, "64k"}])
          FFix.output(mapping, "out.mkv", [{raw, "128k"}])
        end)

      assert_raise ArgumentError, ~r/cannot be combined/, fn -> FFix.to_argv(command) end
    end
  end
end
