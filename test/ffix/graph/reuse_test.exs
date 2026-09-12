defmodule FFix.Graph.ReuseTest do
  use ExUnit.Case, async: true

  alias FFix.{Filter, Graph}
  alias FFix.Graph.{StreamRef, Terminal}

  @ffmpeg System.find_executable("ffmpeg")

  test "bound graph exports compose with filters and infer their input declarations" do
    template = Graph.parse!("[0:v:0]scale=16:16[preview]")
    source = FFix.input("in.mp4")
    instance = Graph.bind(template, %{0 => source})
    assert %StreamRef{} = picture = instance[:preview]
    assert picture == instance[0]
    assert Graph.exports(instance) == [picture]
    assert Graph.terminals(instance) == []

    command = picture |> Filter.hflip() |> FFix.output("out.mp4") |> FFix.command()
    assert command.inputs == [source]
    assert filter_names(command.graph) == [:scale, :hflip]
    assert Enum.map(input_nodes(command.graph), & &1.input_ref.selector) == [{:video, 0}]
  end

  test "parsed out-number labels keep their names and pad addresses" do
    graph = Graph.parse!("[0:v]split[out1][out0]")
    assert Enum.map(graph.exports, & &1.name) == ["out1", "out0"]
    assert graph[:out0].ref.output == 1
    assert graph[:out1].ref.output == 0
    assert Graph.to_filtergraph(graph) == "[0:v]split[out1][out0];"
  end

  test "each binding instantiates fresh template filters, not fresh input declarations" do
    source = FFix.input("in.mp4")
    template = preview_template()
    first = Graph.bind(template, picture: FFix.video(source, 0))
    second = Graph.bind(template, picture: FFix.video(source, 0))

    command =
      FFix.command([
        FFix.output(first[:preview], "one.mp4"),
        FFix.output(second[:preview], "two.mp4")
      ])

    assert command.inputs == [source]
    assert filter_names(command.graph) == [:hflip, :hflip]
  end

  test "bound external producers retain identity and still require explicit splits" do
    source = FFix.input("in.mp4")
    shared = source |> FFix.video(0) |> Filter.scale(w: 16, h: 16)
    instance = Graph.bind(preview_template(), picture: shared)

    assert_raise ArgumentError, ~r/is used 2 times/, fn ->
      FFix.command([FFix.output(instance[:preview], "one.mp4"), FFix.output(shared, "two.mp4")])
    end

    [inside, outside] = Filter.split(shared)
    instance = Graph.bind(preview_template(), picture: inside)

    command =
      FFix.command([FFix.output(instance[:preview], "one.mp4"), FFix.output(outside, "two.mp4")])

    assert Enum.count(filter_names(command.graph), &(&1 == :scale)) == 1
    assert Enum.count(filter_names(command.graph), &(&1 == :split)) == 1
    assert Enum.count(filter_names(command.graph), &(&1 == :hflip)) == 1
  end

  test "nested binding preserves unused external branches until the final command" do
    port = Graph.input(:picture, :video)
    outer = FFix.graph(outputs: [first: Filter.hflip(port), second: Filter.vflip(port)])
    source = FFix.input("in.mp4")
    outer = Graph.bind(outer, picture: FFix.video(source, 0))
    inner = Graph.bind(preview_template(), picture: outer[:first])

    assert_raise ArgumentError, ~r/unconnected filter output/, fn ->
      inner[:preview] |> FFix.output("out.mp4") |> FFix.command()
    end

    command =
      FFix.command([
        FFix.output(inner[:preview], "out.mp4"),
        FFix.output(outer[:second], "other.mp4")
      ])

    assert Enum.count(filter_names(command.graph), &(&1 == :hflip)) == 2
    assert Enum.count(filter_names(command.graph), &(&1 == :vflip)) == 1
    assert command.inputs == [source]
  end

  test "instances retain sink branches and settings without duplicate execution" do
    port = Graph.input(:sound, :audio)
    [picture, sound] = Filter.ebur128(port, video: true)

    template =
      FFix.graph(
        outputs: [meter: picture],
        terminals: [Filter.anullsink(sound)],
        settings: [sws_flags: "bilinear"]
      )

    source = FFix.input("in.mkv")
    instance = Graph.bind(template, sound: FFix.audio(source, 0))
    assert [%Terminal{}] = Graph.terminals(instance)

    command =
      FFix.command(FFix.output(instance[:meter], "out.mkv"), terminals: Graph.terminals(instance))

    assert filter_names(command.graph) == [:ebur128, :anullsink]
    assert length(command.graph.terminals) == 1
    assert command.graph.settings == [sws_flags: "bilinear"]
    assert FFix.to_argv(command) |> Enum.any?(&String.starts_with?(&1, "sws_flags=bilinear;"))
  end

  test "terminal-only instances retain input dependencies and settings" do
    terminal_graph =
      FFix.graph(
        terminals: [Filter.nullsink(Graph.input(:picture, :video))],
        settings: [sws_flags: "bilinear"]
      )

    source = FFix.input("in.mp4")
    instance = Graph.bind(terminal_graph, picture: FFix.video(source, 0))
    assert Graph.exports(instance) == []

    command =
      FFix.command(FFix.output(FFix.audio(source, 0), "audio.mka"),
        terminals: Graph.terminals(instance)
      )

    assert command.inputs == [source]
    assert filter_names(command.graph) == [:nullsink]
    assert length(command.graph.terminals) == 1
    assert command.graph.settings == [sws_flags: "bilinear"]
  end

  test "settings cannot introduce undeclared filters" do
    assert_raise ArgumentError, "unsupported graph setting: testsrc", fn ->
      FFix.graph(output: Filter.hflip(Graph.input(0, :video)), settings: [testsrc: "16x16"])
    end
  end

  test "setting conflicts between composed instances are explicit" do
    source = FFix.input("in.mp4")

    first =
      Graph.bind(%{preview_template() | settings: [sws_flags: "bilinear"]},
        picture: FFix.video(source, 0)
      )

    second =
      Graph.bind(%{preview_template() | settings: [sws_flags: "lanczos"]},
        picture: FFix.video(source, 0)
      )

    assert_raise ArgumentError, ~r/conflicting graph setting/, fn ->
      FFix.command([
        FFix.output(first[:preview], "one.mp4"),
        FFix.output(second[:preview], "two.mp4")
      ])
    end
  end

  test "exact parsed ports can bind independently to filtered video and audio" do
    template = Graph.parse!("[0:v]hflip[picture];[0:a]anull[sound]")
    source = FFix.input("in.mkv")
    picture = Filter.scale(FFix.video(source, 0), w: 16, h: 16)
    sound = Filter.volume(FFix.audio(source, 0), volume: 0.5)
    instance = Graph.bind(template, %{{0, :video} => picture, {0, :audio} => sound})
    command = FFix.command(FFix.output(Graph.exports(instance), "out.mkv"))
    assert command.inputs == [source]
    assert Enum.sort(filter_names(command.graph)) == Enum.sort([:scale, :volume, :hflip, :anull])

    assert_raise ArgumentError, ~r/multiple selectors/, fn ->
      Graph.bind(template, %{0 => picture})
    end

    assert_raise ArgumentError, ~r/multiple bindings/, fn ->
      Graph.bind(template, %{0 => source, {0, :video} => picture})
    end
  end

  test "bindings validate names, media, cardinality, and immutable snapshots" do
    source = FFix.input("in.mp4")
    template = preview_template()
    assert_raise ArgumentError, ~r/unbound graph input/, fn -> Graph.bind(template, []) end

    assert_raise ArgumentError, ~r/unknown graph input bindings/, fn ->
      Graph.bind(template, picture: FFix.video(source, 0), typo: FFix.video(source, 0))
    end

    assert_raise ArgumentError, ~r/expects video, got: audio/, fn ->
      Graph.bind(template, picture: FFix.audio(source, 0))
    end

    assert_raise ArgumentError, ~r/graph inputs bind to Input declarations or StreamRefs/, fn ->
      Graph.bind(template, picture: FFix.video(source, :all))
    end

    first = Graph.bind(template, picture: FFix.video(source, 0))
    changed = %{source | options: [ss: 2]}
    second = Graph.bind(template, picture: FFix.video(changed, 0))

    assert_raise ArgumentError, ~r/conflicting input snapshots/, fn ->
      FFix.command([
        FFix.output(first[:preview], "one.mp4"),
        FFix.output(second[:preview], "two.mp4")
      ])
    end
  end

  test "model edits cannot silently change a producer shared with an earlier snapshot" do
    source = FFix.input("in.mp4")
    picture = FFix.video(source, 0) |> Filter.scale(w: 16, h: 16) |> Filter.hflip()
    graph = FFix.graph(output: picture)
    scale = Enum.find(Graph.nodes(graph), &(&1.name == :scale))
    changed = Graph.update_node(graph, scale.id, &%{&1 | args: [w: 32, h: 32]})

    outputs = [FFix.output(picture, "one.mp4"), FFix.output(changed[0], "two.mp4")]

    Enum.each([outputs, Enum.reverse(outputs)], fn ordered ->
      assert_raise ArgumentError, ~r/conflicting definitions/, fn -> FFix.command(ordered) end
    end)
  end

  @tag skip: is_nil(@ffmpeg)
  test "FFmpeg sees the resized producer on both bound and external branches" do
    source = FFix.Demuxer.lavfi("testsrc2=size=32x32:rate=1")
    shared = source |> FFix.video(0) |> Filter.scale(w: 16, h: 16)
    [inside, outside] = Filter.split(shared)
    instance = Graph.bind(preview_template(), picture: inside)

    streams =
      Enum.map(
        [instance[:preview], Filter.vflip(outside)],
        &FFix.Encoder.encode(&1, "rawvideo", threads: 1)
      )

    output =
      FFix.Muxer.mux(streams, "framehash", :stdout,
        output_options: ["frames:v": 1, flush_packets: true]
      )

    command = FFix.command(output)
    assert {:ok, result} = FFix.run(command, ffmpeg: @ffmpeg, stdout: :collect)
    assert result.stdout =~ "#dimensions 0: 16x16"
    assert result.stdout =~ "#dimensions 1: 16x16"
  end

  @tag skip: is_nil(@ffmpeg)
  test "FFmpeg executes video-first ebur128 with the retained audio sink" do
    [picture, sound] = Filter.ebur128(Graph.input(:sound, :audio), video: true)
    template = FFix.graph(outputs: [picture: picture], terminals: [Filter.anullsink(sound)])
    instance = Graph.bind(template, sound: Filter.sine(frequency: 440, duration: 0.2))

    output =
      FFix.Muxer.mux(
        FFix.Encoder.encode(instance[:picture], "rawvideo", threads: 1),
        "framehash",
        :stdout,
        output_options: ["frames:v": 1]
      )

    command = FFix.command(output)
    assert command.inputs == []
    assert {:ok, result} = FFix.run(command, ffmpeg: @ffmpeg, stdout: :collect)
    assert result.stdout =~ "#dimensions 0: 640x480"
    assert length(command.graph.terminals) == 1
  end

  defp preview_template do
    FFix.graph(outputs: [preview: Filter.hflip(Graph.input(:picture, :video))])
  end

  defp filter_names(graph) do
    graph |> Graph.nodes() |> Enum.filter(&(&1.kind == :filter)) |> Enum.map(& &1.name)
  end

  defp input_nodes(graph), do: Enum.filter(Graph.nodes(graph), &(&1.kind == :input))
end
