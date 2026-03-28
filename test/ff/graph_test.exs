defmodule FF.GraphTest do
  use ExUnit.Case, async: true

  alias FF.Filter

  test "builds a sink-only graph" do
    sink =
      FF.input(0, :video)
      |> Filter.showinfo()
      |> Filter.nullsink()

    graph = FF.graph(terminals: [sink])

    assert graph.exports == []
    assert length(graph.terminals) == 1

    assert FF.to_filtergraph(graph) ==
             """
             [0:v]showinfo[showinfo_0];
             [showinfo_0]nullsink;
             """
             |> String.trim()
  end

  test "builds a graph with exported outputs, sinks, and graph settings" do
    video = FF.input(0, :video)
    [main, debug] = Filter.split(video, outputs: 2)

    sink =
      debug
      |> Filter.showinfo()
      |> Filter.nullsink()

    graph =
      FF.graph(
        outputs: [video: main],
        terminals: [sink],
        settings: [sws_flags: [:accurate_rnd, :full_chroma_int]]
      )

    graph = FF.validate!(graph)

    assert Enum.map(graph.exports, & &1.name) == [:video]
    assert length(graph.terminals) == 1

    assert FF.to_filtergraph(graph) ==
             """
             sws_flags=accurate_rnd+full_chroma_int;
             [0:v]split=outputs=2[video][split_1];
             [split_1]showinfo[showinfo_0];
             [showinfo_0]nullsink;
             """
             |> String.trim()
  end

  test "graphs reject unknown top-level keys" do
    assert_raise ArgumentError, "unknown graph keys: [:metadata]", fn ->
      FF.graph(outputs: [video: FF.input(0, :video)], metadata: %{debug: true})
    end
  end
end
