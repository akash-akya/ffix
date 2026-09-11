defmodule FFix.Graph.InvariantsTest do
  use ExUnit.Case, async: true

  alias FFix.{Command, Filter, Graph}
  alias FFix.Graph.{Ref, Terminal}

  test "filter pads have exactly one consumer, including exports and sink branches" do
    picture = Graph.input(0, :video) |> Filter.scale(w: 16, h: 16)

    graphs = [
      FFix.graph(outputs: [Filter.hflip(picture), Filter.vflip(picture)]),
      FFix.graph(outputs: [picture, Filter.hflip(picture)]),
      FFix.graph(outputs: [picture, picture]),
      FFix.graph(output: picture, terminals: [Filter.nullsink(picture)]),
      FFix.graph(terminals: [Filter.nullsink(picture), Filter.nullsink(picture)])
    ]

    for graph <- graphs do
      assert_raise ArgumentError, ~r/used 2 times.*split\/asplit/, fn -> FFix.validate!(graph) end
    end
  end

  test "direct input selections may have multiple consumers" do
    picture = Graph.input(0, :video)

    assert %Graph{} =
             FFix.graph(outputs: [Filter.hflip(picture), Filter.vflip(picture)])
             |> FFix.validate!()

    assert %Graph{} = FFix.graph(outputs: [picture, picture]) |> FFix.validate!()
  end

  test "every mixed output pad survives regardless of root traversal order" do
    [first, sound, last] = Filter.filter([], "mixed_source", [:video, :audio, :video])
    terminals = [Filter.nullsink(first), Filter.anullsink(sound)]

    for roots <- [terminals, Enum.reverse(terminals)] do
      graph = FFix.graph(outputs: [last: last], terminals: roots) |> FFix.validate!()
      producer = Enum.find(Graph.nodes(graph), &(&1.name == "mixed_source"))
      assert producer.outputs == 3
      assert producer.output_media == [:video, :audio, :video]
      assert graph[:last].ref.output == 2
      assert length(graph.terminals) == 2
      text = FFix.to_filtergraph(graph)
      parsed = Graph.nodes(graph)
      assert length(Enum.filter(parsed, &(&1.outputs == 0))) == 2
      assert text =~ "nullsink;"
      assert text =~ "anullsink;"
    end
  end

  test "split pads must be exported or connected, even when a terminal value was built" do
    for count <- 2..5 do
      streams = Filter.split(Graph.input(0, :video), outputs: count)
      [kept | discarded] = streams
      terminals = Enum.map(discarded, &Filter.nullsink/1)
      graph = FFix.graph(output: kept, terminals: terminals)
      assert %Graph{} = FFix.validate!(graph)
      assert length(graph.terminals) == count - 1

      assert_raise ArgumentError, ~r/unconnected filter output/, fn ->
        FFix.graph(output: kept, terminals: tl(terminals)) |> FFix.validate!()
      end
    end
  end

  test "zero-output filters are explicit terminals, not missing singleton outputs" do
    assert %Terminal{} = sink = Filter.split(Graph.input(0, :video), outputs: 0)
    graph = FFix.graph(terminals: [sink]) |> FFix.validate!()
    assert graph.exports == []
    assert length(graph.terminals) == 1
    assert FFix.to_filtergraph(graph) == "[0:v]split=outputs=0;"
    assert length(Graph.parse!(FFix.to_filtergraph(graph)).terminals) == 1
  end

  test "every disconnected sink root and its dependencies are retained" do
    terminals = [Filter.testsrc() |> Filter.nullsink(), Filter.sine() |> Filter.anullsink()]
    graph = FFix.graph(terminals: terminals) |> FFix.validate!()
    assert length(graph.order) == 4
    assert length(graph.terminals) == 2
    assert length(Graph.parse!(FFix.to_filtergraph(graph)).terminals) == 2

    assert_raise ArgumentError, ~r/every sink exactly once/, fn ->
      FFix.validate!(%{graph | terminals: tl(graph.terminals)})
    end

    assert_raise ArgumentError, ~r/every sink exactly once/, fn ->
      FFix.validate!(%{graph | terminals: graph.terminals ++ graph.terminals})
    end
  end

  test "graph exports carry owner identity, while wire output stays deterministic" do
    video = Graph.input(0, :video)
    small = FFix.graph(output: Filter.scale(video, w: 320, h: -2))
    large = FFix.graph(output: Filter.scale(video, w: 640, h: -2))
    assert small[0].ref == large[0].ref
    refute small[0] == large[0]
    refute small.id == large.id

    command =
      Command.new(
        inputs: [FFix.input("input.mp4")],
        graph: large,
        outputs: [FFix.output(small[0], "out.mp4")]
      )

    assert_raise ArgumentError, ~r/not exported by the command graph/, fn ->
      FFix.to_argv(command)
    end

    first = FFix.graph(output: video |> Filter.hflip())
    second = FFix.graph(output: video |> Filter.hflip())
    assert first.id != second.id
    assert FFix.to_filtergraph(first) == FFix.to_filtergraph(second)
  end

  test "duplicate logical names and duplicate parsed labels fail explicitly" do
    [first, second] = Filter.split(Graph.input(0, :video))
    graph = FFix.graph(outputs: [same: first, same: second])
    assert_raise ArgumentError, ~r/duplicate graph export name/, fn -> FFix.validate!(graph) end

    assert_raise ArgumentError, ~r/duplicate graph label/, fn ->
      Graph.parse!("[0:v]split[same][same]")
    end
  end

  test "inconsistent plan definitions cannot depend on traversal order" do
    original = Filter.null(Graph.input(0, :video))
    changed = FFix.shape(original, [:unknown])

    for outputs <- [[original, changed], [changed, original]] do
      assert_raise ArgumentError, ~r/conflicting definitions/, fn ->
        FFix.graph(outputs: outputs)
      end
    end

    assert_raise ArgumentError, ~r/complete ordered result/, fn ->
      FFix.shape(Graph.input(0, :video), [:video, :audio])
    end

    [_first, second] = Filter.split(Graph.input(0, :video))

    assert_raise ArgumentError, ~r/complete ordered result/, fn ->
      FFix.shape(second, [:video])
    end
  end

  test "unresolved output counts cannot be guessed from encountered labels or references" do
    unresolved = Filter.extractplanes(Graph.input(0, :video), planes: "y+u")

    assert_raise ArgumentError, ~r/unresolved filter output shape/, fn ->
      FFix.graph(output: unresolved)
    end

    assert_raise ArgumentError, ~r/unresolved filter output shape/, fn ->
      Graph.parse!("[0:v]extractplanes=planes=y+u[y][u]")
    end
  end

  test "internal labels take precedence over external input syntax" do
    for label <- ["1", "0:v", "0:v:0"] do
      graph = Graph.parse!("testsrc=size=16x16[#{label}];[#{label}]hflip[out]")
      assert length(graph.exports) == 1
      assert length(graph.order) == 2
      assert Enum.all?(Graph.nodes(graph), &(&1.kind == :filter))
      [producer, consumer] = Graph.nodes(graph)
      assert consumer.inputs == [%Ref{node_id: producer.id, output: 0}]
    end

    assert_raise ArgumentError, ~r/forward or cyclic graph label/, fn ->
      Graph.parse!("[1]hflip[out];testsrc[1]")
    end
  end

  test "raw selectors are escaped only at the graph label boundary" do
    for selector <- ["m:title:a]b", "m:title:it's", "m:title:a\\b", "m:title: trailing "] do
      graph = Graph.input(0, {:raw, selector}) |> Filter.null() |> then(&FFix.graph(output: &1))
      rendered = FFix.to_filtergraph(graph)
      parsed = Graph.parse!(rendered)
      input = Enum.find(Graph.nodes(parsed), &(&1.kind == :input))
      assert input.input_ref.selector == {:raw, selector}
      assert FFix.to_filtergraph(parsed) == rendered

      command =
        Command.new(
          inputs: [FFix.input("in.mp4")],
          outputs: [FFix.output(Graph.input(0, {:raw, selector}), "out.mp4")]
        )

      assert "0:#{selector}" in FFix.to_argv(command)
    end
  end

  test "duplicate root collection keys cannot discard a branch" do
    video = Graph.input(0, :video)

    assert_raise ArgumentError, ~r/duplicate graph option/, fn ->
      FFix.graph(outputs: [Filter.hflip(video)], outputs: [Filter.vflip(video)])
    end
  end

  test "invalid ordering and pad addresses fail before rendering" do
    graph = FFix.graph(output: Graph.input(0, :video) |> Filter.hflip())
    export = graph[0]

    for bad <- [
          %{graph | order: Enum.reverse(graph.order)},
          %{graph | order: graph.order ++ graph.order},
          %{graph | order: tl(graph.order)},
          %{graph | exports: [%{export | ref: %Ref{node_id: export.ref.node_id, output: -1}}]},
          %{graph | exports: [%{export | ref: %Ref{node_id: export.ref.node_id, output: 1}}]}
        ] do
      assert_raise ArgumentError, fn -> Graph.to_filtergraph(bad) end
    end
  end

  test "materialized nodes and settings are revalidated before rendering" do
    graph = FFix.graph(output: Graph.input(0, :video) |> Filter.hflip())
    node = Enum.find(Graph.nodes(graph), &(&1.kind == :filter))

    for invalid_node <- [
          %{node | name: "null;injected"},
          %{node | instance: "bad;name"},
          %{node | args: [{"text;injected", "value"}]},
          %{node | args: [text: "bad\0text"]},
          %{node | args: [text: fn -> flunk("must not run") end]},
          %{node | output_media: [:audio]}
        ] do
      invalid = %{graph | nodes: Map.put(graph.nodes, node.id, invalid_node)}
      assert_raise ArgumentError, fn -> Graph.to_filtergraph(invalid) end
    end

    for settings <- [
          nil,
          [{"sws_flags;injected", "value"}],
          [sws_flags: "bad\0text"],
          [sws_flags: "fast_bilinear", sws_flags: "lanczos"]
        ] do
      assert_raise ArgumentError, fn -> Graph.to_filtergraph(%{graph | settings: settings}) end
    end
  end

  test "file-loaded pad counts are not guessed or read" do
    assert_raise ArgumentError, ~r/unresolved filter output shape/, fn ->
      Graph.parse!("[0:v]split=/outputs=/not/read/by/ffix[left][right]")
    end
  end

  test "parsing retains terminal branches and rejects double consumption" do
    graph = Graph.parse!("[0:a]ebur128=video=true[picture][sound];[sound]anullsink")
    assert Enum.map(graph.exports, & &1.media) == [:video]
    assert length(graph.terminals) == 1
    producer = Enum.find(Graph.nodes(graph), &(&1.name == :ebur128))
    assert producer.output_media == [:video, :audio]

    assert_raise ArgumentError, ~r/used 2 times/, fn ->
      Graph.parse!("[0:v]scale=16:16[shared];[shared]hflip[left];[shared]nullsink")
    end
  end
end
