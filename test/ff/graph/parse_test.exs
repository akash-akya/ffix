defmodule FF.Graph.ParseTest do
  use ExUnit.Case, async: true

  alias FF.Filter
  alias FF.Graph

  test "round-trips a rendered graph with an unnamed export" do
    graph =
      FF.stream_ref(0, :video)
      |> Filter.scale(w: 1280, h: -1)
      |> Filter.drawtext(text: "Hello", x: FF.expr("w-tw-20"), y: 20)
      |> then(&FF.graph(output: &1))

    rendered = FF.to_filtergraph(graph)
    parsed = Graph.parse!(rendered)

    assert Enum.map(parsed.exports, & &1.name) == [nil]
    assert FF.to_filtergraph(parsed) == rendered
  end

  test "round-trips a rendered graph with settings, exports, and terminals" do
    video = FF.stream_ref(0, :video)
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

    assert Enum.map(parsed.exports, & &1.name) == ["video"]
    assert parsed[:video] == parsed["video"]
    assert length(parsed.terminals) == 1
    assert FF.to_filtergraph(parsed) == rendered
  end

  test "round-trips rendered graphs with escaped values" do
    graphs = [
      FF.graph(
        outputs: [
          video: FF.stream_ref(0, :video) |> Filter.drawtext(text: "hello, world", x: 20, y: 20)
        ]
      ),
      FF.graph(
        outputs: [
          video:
            FF.stream_ref(0, :video)
            |> Filter.drawtext(text: "hello:world", x: FF.expr("w-tw-20"), y: 20)
        ]
      ),
      FF.graph(
        outputs: [
          video: FF.stream_ref(0, :video) |> Filter.drawtext(text: "hello;world", x: 20, y: 20)
        ]
      ),
      FF.graph(
        outputs: [
          video: FF.stream_ref(0, :video) |> Filter.drawtext(text: "hello[world]", x: 20, y: 20)
        ]
      ),
      FF.graph(
        outputs: [
          video: FF.stream_ref(0, :video) |> Filter.drawtext(text: "it\'s\\ok", x: 20, y: 20)
        ]
      )
    ]

    Enum.each(graphs, fn graph ->
      rendered = FF.to_filtergraph(graph)
      parsed = Graph.parse!(rendered)
      assert FF.to_filtergraph(parsed) == rendered
    end)
  end

  test "parses comma-separated chains with implicit links and normalizes them" do
    source = "testsrc,split[L1],hflip[L2];[L1][L2]hstack"

    assert FF.to_filtergraph(Graph.parse!(source)) ==
             """
             testsrc[testsrc_0];
             [testsrc_0]split[L1][split_1];
             [split_1]hflip[L2];
             [L1][L2]hstack[out0];
             """
             |> String.trim()
  end

  test "normalizes quoted values without losing meaning" do
    assert FF.to_filtergraph(Graph.parse!(~S([0:v]drawtext=text='hello, world':x=20:y=20[video]))) ==
             ~S([0:v]drawtext=text=hello\, world:x=20:y=20[video];)

    assert FF.to_filtergraph(Graph.parse!(~S([0:v]drawtext=text='it\'s:ok':x=20:y=20[video]))) ==
             ~S([0:v]drawtext=text=it\'s\:ok:x=20:y=20[video];)
  end

  test "parses explicitly labeled dynamic outputs we render via shape/2" do
    graph =
      FF.stream_ref(0, :audio)
      |> Filter.ebur128(video: true)
      |> FF.shape([:audio, :video])
      |> then(fn [audio, video] -> FF.graph(outputs: [audio: audio, video: video]) end)

    rendered = FF.to_filtergraph(graph)
    assert FF.to_filtergraph(Graph.parse!(rendered)) == rendered
  end

  test "parses shaped concat graphs with one explicit output" do
    graph =
      [FF.stream_ref(0, :video), FF.stream_ref(1, :video)]
      |> Filter.concat()
      |> FF.shape([:video])
      |> then(&FF.graph(outputs: [video: &1]))

    rendered = FF.to_filtergraph(graph)
    assert FF.to_filtergraph(Graph.parse!(rendered)) == rendered
  end

  test "parses mixed positional and named args" do
    source = "[0:v]fade=in:0:30:alpha=1[out]"

    assert FF.to_filtergraph(Graph.parse!(source)) == source <> ";"
  end

  test "normalizes whitespace without changing meaning" do
    source = " [0:v] scale = w=1280:h=-1 [video] ; "

    assert FF.to_filtergraph(Graph.parse!(source)) == "[0:v]scale=w=1280:h=-1[video];"
  end

  test "ffmpeg accepts a round-tripped source graph" do
    source = "testsrc,split[L1],hflip[L2];[L1][L2]hstack"
    graph = source |> Graph.parse!() |> FF.to_filtergraph()

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
