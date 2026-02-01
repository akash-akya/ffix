defmodule FF.Graph.ParseTest do
  use ExUnit.Case, async: true

  alias FF.Filter
  alias FF.Graph

  test "round-trips a rendered graph with an unnamed export" do
    graph =
      FF.input(0, :video)
      |> Filter.scale(w: 1280, h: -1)
      |> Filter.drawtext(text: "Hello", x: FF.expr("w-tw-20"), y: 20)
      |> then(&FF.graph(output: &1))

    rendered = FF.to_filtergraph(graph)
    parsed = Graph.parse!(rendered)

    assert Enum.map(parsed.exports, & &1.name) == [nil]
    assert FF.to_filtergraph(parsed) == rendered
  end

  test "round-trips a rendered graph with settings, exports, and terminals" do
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

    rendered = FF.to_filtergraph(graph)
    parsed = Graph.parse!(rendered)

    assert Enum.map(parsed.exports, & &1.name) == [:video]
    assert length(parsed.terminals) == 1
    assert FF.to_filtergraph(parsed) == rendered
  end
end
