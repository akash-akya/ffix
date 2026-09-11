defmodule FFix.OutputFirstTest do
  use ExUnit.Case, async: true

  alias FFix.Command
  alias FFix.Command.Build
  alias FFix.Command.Input
  alias FFix.Command.Mapping
  alias FFix.Command.Output
  alias FFix.Decoder
  alias FFix.Encoder
  alias FFix.Graph
  alias FFix.Graph.Builder
  alias FFix.Graph.InputRef

  test "direct mappings infer declaration order and do not emit an empty graph" do
    first = Input.new("same.mp4")
    second = Input.new("same.mp4", ss: 2)

    output =
      Output.new(
        [
          Input.select(second, {:audio, 0}),
          Input.select(first, {:video, 0}),
          Input.select(second, {:video, 0})
        ],
        "out.mkv"
      )

    command = Build.command(output)

    assert command.inputs == [second, first]
    assert command.graph == nil

    assert Command.to_argv(command) == [
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
    first = Input.new("first.mp4")
    second = Input.new("second.mp4")
    metadata = Input.new("metadata.txt")
    output = Output.new(Input.select(second, {:video, 0}), "out.mp4")
    command = Build.command(output, inputs: [first, metadata, second, second])

    assert command.inputs == [first, metadata, second]
    assert "2:v:0" in Command.to_argv(command)
  end

  test "captured configurations must agree with each other and explicit declarations" do
    original = Input.new("in.mp4")
    configured = Decoder.decode(original, "h264", {:video, 0}, threads: 2)
    old_stream = Input.select(original, {:video, 0})
    new_stream = Input.select(configured, {:audio, 0})

    assert_raise ArgumentError, ~r/conflicting input snapshots/, fn ->
      Build.command(Output.new([old_stream, new_stream], "out.mkv"))
    end

    assert_raise ArgumentError, ~r/conflicting input snapshots/, fn ->
      Build.command(Output.new(old_stream, "out.mkv"), inputs: [configured])
    end

    assert_raise ArgumentError, ~r/conflicting input snapshots/, fn ->
      Build.command(Output.new(new_stream, "out.mkv"), inputs: [original, configured])
    end

    assert_raise ArgumentError, ~r/missing from explicit/, fn ->
      Build.command(Output.new(new_stream, "out.mkv"), inputs: [])
    end
  end

  test "unbound positional refs require explicit declarations" do
    output = Output.new(Builder.input(0, {:video, 0}), "out.mp4")
    assert_raise ArgumentError, ~r/unbound input reference/, fn -> Build.command(output) end
    command = Build.command(output, inputs: [Input.new("in.mp4")])
    assert "0:v:0" in Command.to_argv(command)

    assert_raise ArgumentError, ~r/not declared/, fn ->
      Build.command(Output.new(Builder.input(2, :video), "out.mp4"),
        inputs: [Input.new("in.mp4")]
      )
    end

    assert_raise ArgumentError, ~r/unbound input reference/, fn ->
      Build.command(Output.new(Builder.input(:main, :video), "out.mp4"))
    end
  end

  test "selectors capture complete immutable declarations and preserve FFmpeg suffixes" do
    input = Input.new("in.mkv")

    selectors = [
      :all,
      {:video, :all},
      {:audio, 2},
      {:subtitle, 1},
      {:data, 0},
      {:attachment, 0},
      {:index, 4},
      {:raw, "s?"}
    ]

    streams = Enum.map(selectors, &Input.select(input, &1))
    assert Enum.all?(streams, &(&1.plan.input_ref.declaration == input))

    assert Enum.map(selectors, &InputRef.selector_string/1) == [
             "",
             "v",
             "a:2",
             "s:1",
             "d:0",
             "t:0",
             "4",
             "s?"
           ]

    assert Enum.map(selectors, &InputRef.single?/1) == [
             false,
             false,
             true,
             true,
             true,
             true,
             true,
             false
           ]

    argv = streams |> Output.new("out.mkv") |> Build.command() |> Command.to_argv()

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

  test "public input selection rejects legacy and invalid selectors" do
    input = Input.new("in.mp4")

    for selector <- [:video, :input, {:video, -1}, {:index, -1}, {:raw, ""}, {:raw, "v\0"}] do
      assert_raise ArgumentError, fn -> Input.select(input, selector) end
    end

    refute function_exported?(Input, :fetch, 2)
    assert InputRef.normalize_selector!(:video) == :video
  end

  test "decoder configuration replaces a selector and generic codec names remain literal" do
    input =
      Input.new("in.mkv")
      |> Decoder.decode("old", {:subtitle, 0}, threads: 2)
      |> Decoder.decode("new", {:subtitle, 0}, threads: 3)

    assert input.decoders[{:subtitle, 0}] == Decoder.new("new", [{"threads", 3}])
    output = input |> Input.select({:video, 0}) |> Encoder.encode("h264") |> Output.new("out.mkv")
    argv = output |> Build.command() |> Command.to_argv()
    assert "-c:s:0" in argv
    assert "new" in argv
    assert "h264" in argv
    refute "libx264" in argv

    assert_raise ArgumentError, ~r/expected an indexed video selector/, fn ->
      Decoder.h264(input, {:audio, 0})
    end
  end

  test "callbacks count all five media types in output order and run only on serialization" do
    input = Input.new("in.mkv")

    sources = [
      Input.select(input, {:audio, 0}),
      {:captions, Input.select(input, {:subtitle, 0})},
      {:sound, Input.select(input, {:audio, 1})},
      {:data, Input.select(input, {:data, 0})},
      {:cover, Input.select(input, {:attachment, 0})},
      {:main, Input.select(input, {:video, 0})}
    ]

    callback = fn streams ->
      send(self(), {:streams, streams})
      "value"
    end

    command = Build.command(Output.new(sources, "out.mkv", metadata: callback))
    Command.validate!(command)
    refute_received {:streams, _}
    Command.to_argv(command)

    assert_received {:streams,
                     %{
                       captions: %{index: 1, specifier: "s:0"},
                       sound: %{index: 2, specifier: "a:1"},
                       data: %{index: 3, specifier: "d:0"},
                       cover: %{index: 4, specifier: "t:0"},
                       main: %{index: 5, specifier: "v:0"}
                     }}

    refute_received {:streams, _}
    Command.to_argv(command)
    assert_received {:streams, _}
    refute_received {:streams, _}
  end

  test "callbacks reject plural, optional, and unknown-media absolute selections without evaluation" do
    input = Input.new("in.mkv")

    for selector <- [:all, {:audio, :all}, {:raw, "a?"}, {:index, 0}] do
      output =
        Output.new(Input.select(input, selector), "out.mkv",
          metadata: fn _ -> flunk("must not run") end
        )

      assert_raise ArgumentError, ~r/output option callbacks require/, fn ->
        Build.command(output)
      end
    end
  end

  test "callback errors propagate and nil callback results are invalid" do
    source = Input.new("in.mp4") |> Input.select({:video, 0})

    command =
      Build.command(
        Output.new(source, "out.mp4", metadata: fn streams -> streams.missing.index end)
      )

    assert_raise KeyError, fn -> Command.to_argv(command) end
    command = Build.command(Output.new(source, "out.mp4", metadata: fn _ -> nil end))

    assert_raise ArgumentError, ~r/nil is not a CLI option value/, fn ->
      Command.to_argv(command)
    end
  end

  test "raw switches and booleans have distinct serialization" do
    source = Input.new("in.mp4", enabled: true) |> Input.select({:video, 0})
    command = Build.command(Output.new(source, "out.mp4", enabled: false), global: [y: :flag])

    assert Command.to_argv(command) == [
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
      Input.new("in.mp4", y: nil)
    end

    assert_raise ArgumentError, ~r/nil is not a CLI option value/, fn ->
      Output.new(source, "out.mp4", y: nil)
    end
  end

  test "filtered sources infer dependencies and must be consumed exactly once" do
    source = Input.new("in.mp4") |> Input.select({:video, 0})
    filtered = Builder.filter(source, "null", [:video], [])
    command = Build.command(Output.new(filtered, "out.mp4"))
    assert command.graph != nil
    assert "-filter_complex" in Command.to_argv(command)
    assert [%Input{source: "in.mp4"}] = command.inputs

    assert_raise ArgumentError, fn ->
      Build.command([Output.new(filtered, "one.mp4"), Output.new(filtered, "two.mp4")])
    end

    assert_raise ArgumentError, ~r/cannot copy a filtered source/, fn ->
      Build.command(Output.new(Mapping.new(filtered, :copy), "out.mp4"))
    end
  end

  test "terminal dependencies and graph settings survive command construction" do
    source = Input.new("main.mp4") |> Input.select({:video, 0})
    terminal_source = Input.new("sink.mp4") |> Input.select({:audio, 0})
    terminal = Builder.filter(terminal_source, "anullsink", [], [])

    command =
      Build.command(Output.new(source, "out.mp4"),
        terminals: [terminal],
        settings: [sws_flags: "bicubic"]
      )

    assert Enum.map(command.inputs, & &1.source) == ["main.mp4", "sink.mp4"]
    assert command.graph.settings == [sws_flags: "bicubic"]
    assert "-filter_complex" in Command.to_argv(command)

    assert_raise ArgumentError, ~r/settings require filter nodes/, fn ->
      Build.command(Output.new(source, "out.mp4"), settings: [sws_flags: "bicubic"])
    end
  end

  test "bare canonical exports are reserved for low-level explicit graph commands" do
    input = Input.new("in.mp4")
    source = Input.select(input, {:video, 0})
    graph = Builder.graph(outputs: [source])
    output = Output.new(hd(graph.exports), "out.mp4")

    assert_raise ArgumentError, ~r/bare graph Export.*graph\[:name\]/, fn ->
      Build.command(output)
    end

    assert "0:v:0" in Command.to_argv(
             Command.new(inputs: [input], graph: graph, outputs: [output])
           )
  end

  test "low-level appenders accept existing declarations and old mapping shortcuts are gone" do
    input = Input.new("in.mp4")
    output = Output.new(Input.select(input, {:video, 0}), "out.mp4")
    command = Command.new() |> Command.add_input(input) |> Command.add_output(output)
    assert command.inputs == [input]
    assert command.outputs == [output]
    refute function_exported?(Command, :input, 2)
    refute function_exported?(Command, :output, 3)

    for source <- [:main, 0] do
      assert_raise ArgumentError, fn -> Mapping.new(source) end
    end
  end

  test "direct references retain context terminal dependencies and settings" do
    direct = Input.new("main.mp4") |> Input.select({:video, 0})
    sink_source = Input.new("sink.mp4") |> Input.select({:audio, 0})
    terminal = Builder.filter(sink_source, "anullsink", [], [])
    context = %{id: make_ref(), roots: [direct, terminal], settings: [sws_flags: "bicubic"]}
    contextual = %{direct | context: context}
    command = Build.command(Output.new([contextual, contextual], "out.mp4"))

    assert Enum.map(command.inputs, & &1.source) == ["main.mp4", "sink.mp4"]
    assert length(command.graph.terminals) == 1
    assert command.graph.settings == [sws_flags: "bicubic"]
    assert "-filter_complex" in Command.to_argv(command)

    assert_raise ArgumentError, ~r/conflicting graph setting/, fn ->
      Build.command(Output.new(contextual, "out.mp4"), settings: [sws_flags: "neighbor"])
    end
  end

  test "mapped stream occurrences do not hide conflicting producer definitions" do
    source = Input.new("in.mp4") |> Input.select({:video, 0})
    filtered = Builder.filter(source, "null", [:video], [])
    conflicting = %{filtered | plan: %{filtered.plan | name: "hflip"}}

    assert_raise ArgumentError, ~r/conflicting definitions/, fn ->
      Build.command(Output.new([filtered, conflicting], "out.mp4"))
    end
  end

  test "encoder and muxer callbacks resolve once each per serialization" do
    source = Input.new("in.mp4") |> Input.select({:video, 0})

    mapping =
      Encoder.encode(source, "h264",
        threads: fn _ ->
          send(self(), :encoder)
          2
        end
      )

    muxer =
      FFix.Muxer.new("mp4", [
        {"movflags",
         fn _ ->
           send(self(), :muxer)
           "faststart"
         end}
      ])

    command = Build.command(Output.new(mapping, "out.mp4", muxer: muxer))
    Command.validate!(command)
    refute_received :encoder
    refute_received :muxer
    argv = Command.to_argv(command)
    assert "faststart" in argv
    assert_received :encoder
    assert_received :muxer
    refute_received :encoder
    refute_received :muxer
  end

  test "output-first construction rejects callback and old keyword construction modes" do
    assert_raise ArgumentError, fn -> Build.command(fn _ -> flunk("must not run") end) end
    assert_raise ArgumentError, fn -> Build.command(outputs: []) end
    assert_raise ArgumentError, fn -> Build.command([], graph: %Graph{}) end
  end
end
