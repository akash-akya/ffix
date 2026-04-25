defmodule FFix.Graph.ParseTest do
  use ExUnit.Case, async: true

  alias FFix.Filter
  alias FFix.Graph

  test "round-trips a rendered graph with an unnamed export" do
    graph =
      FFix.Graph.input(0, :video)
      |> Filter.scale(w: 1280, h: -1)
      |> Filter.drawtext(text: "Hello", x: FFix.expr("w-tw-20"), y: 20)
      |> then(&FFix.graph(output: &1))

    rendered = FFix.to_filtergraph(graph)
    parsed = Graph.parse!(rendered)

    assert Enum.map(parsed.exports, & &1.name) == [nil]
    assert FFix.to_filtergraph(parsed) == rendered
  end

  test "round-trips a rendered graph with settings, exports, and terminals" do
    video = FFix.Graph.input(0, :video)
    [main, debug] = Filter.split(video, outputs: 2)

    sink =
      debug
      |> Filter.showinfo()
      |> Filter.nullsink()

    graph =
      FFix.graph(
        outputs: [video: main],
        terminals: [sink],
        settings: [sws_flags: [:accurate_rnd, :full_chroma_int]]
      )

    rendered = FFix.to_filtergraph(graph)
    parsed = Graph.parse!(rendered)

    assert Enum.map(parsed.exports, & &1.name) == ["video"]
    assert parsed[:video] == parsed["video"]
    assert length(parsed.terminals) == 1
    assert FFix.to_filtergraph(parsed) == rendered
  end

  test "round-trips rendered graphs with escaped values" do
    graphs = [
      FFix.graph(
        outputs: [
          video:
            FFix.Graph.input(0, :video) |> Filter.drawtext(text: "hello, world", x: 20, y: 20)
        ]
      ),
      FFix.graph(
        outputs: [
          video:
            FFix.Graph.input(0, :video)
            |> Filter.drawtext(text: "hello:world", x: FFix.expr("w-tw-20"), y: 20)
        ]
      ),
      FFix.graph(
        outputs: [
          video: FFix.Graph.input(0, :video) |> Filter.drawtext(text: "hello;world", x: 20, y: 20)
        ]
      ),
      FFix.graph(
        outputs: [
          video:
            FFix.Graph.input(0, :video) |> Filter.drawtext(text: "hello[world]", x: 20, y: 20)
        ]
      ),
      FFix.graph(
        outputs: [
          video: FFix.Graph.input(0, :video) |> Filter.drawtext(text: "it\'s\\ok", x: 20, y: 20)
        ]
      )
    ]

    Enum.each(graphs, fn graph ->
      rendered = FFix.to_filtergraph(graph)
      parsed = Graph.parse!(rendered)
      assert FFix.to_filtergraph(parsed) == rendered
    end)
  end

  test "parses comma-separated chains with implicit links and normalizes them" do
    source = "testsrc,split[L1],hflip[L2];[L1][L2]hstack"

    assert FFix.to_filtergraph(Graph.parse!(source)) ==
             """
             testsrc[testsrc_0];
             [testsrc_0]split[L1][split_1];
             [split_1]hflip[L2];
             [L1][L2]hstack[out0];
             """
             |> String.trim()
  end

  test "normalizes quoted values without losing meaning" do
    assert FFix.to_filtergraph(
             Graph.parse!(~S([0:v]drawtext=text='hello, world':x=20:y=20[video]))
           ) ==
             ~S([0:v]drawtext=text=hello\, world:x=20:y=20[video];)

    assert FFix.to_filtergraph(Graph.parse!(~S([0:v]drawtext=text='it\'s:ok':x=20:y=20[video]))) ==
             ~S([0:v]drawtext=text=it\'s\:ok:x=20:y=20[video];)
  end

  test "parses explicitly labeled dynamic outputs we render via shape/2" do
    graph =
      FFix.Graph.input(0, :audio)
      |> Filter.ebur128(video: true)
      |> FFix.shape([:audio, :video])
      |> then(fn [audio, video] -> FFix.graph(outputs: [audio: audio, video: video]) end)

    rendered = FFix.to_filtergraph(graph)
    assert FFix.to_filtergraph(Graph.parse!(rendered)) == rendered
  end

  test "parses shaped concat graphs with one explicit output" do
    graph =
      [FFix.Graph.input(0, :video), FFix.Graph.input(1, :video)]
      |> Filter.concat()
      |> FFix.shape([:video])
      |> then(&FFix.graph(outputs: [video: &1]))

    rendered = FFix.to_filtergraph(graph)
    assert FFix.to_filtergraph(Graph.parse!(rendered)) == rendered
  end

  test "parses mixed positional and named args" do
    source = "[0:v]fade=in:0:30:alpha=1[out]"

    assert FFix.to_filtergraph(Graph.parse!(source)) == source <> ";"
  end

  test "normalizes whitespace without changing meaning" do
    source = " [0:v] scale = w=1280:h=-1 [video] ; "

    assert FFix.to_filtergraph(Graph.parse!(source)) == "[0:v]scale=w=1280:h=-1[video];"
  end

  test "ffmpeg accepts a round-tripped source graph" do
    source = "testsrc,split[L1],hflip[L2];[L1][L2]hstack"
    graph = source |> Graph.parse!() |> FFix.to_filtergraph()

    {_output, 0} =
      System.cmd("ffmpeg", [
        "-v",
        "error",
        "-f",
        "lavfi",
        "-i",
        graph,
        "-frames:v",
        "1",
        "-f",
        "null",
        "-"
      ])
  end
end
