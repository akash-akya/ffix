defmodule FFix.Filter.BuilderTest do
  use ExUnit.Case, async: true

  alias FFix.Filter
  alias FFix.Graph

  test "generated wrappers reject unknown options" do
    video = FFix.Graph.input(0, :video)

    assert_raise ArgumentError, "foo is not a valid option", fn ->
      Filter.scale(video, foo: 1)
    end
  end

  test "uses metadata defaults for dynamic output filters" do
    assert [left, right] = Filter.split(FFix.Graph.input(0, :video))
    assert left.output == 0
    assert right.output == 1
  end

  test "concat infers mixed output media from v/a options" do
    [video, audio] =
      Filter.concat(
        [
          FFix.Graph.input(0, :video),
          FFix.Graph.input(0, :audio),
          FFix.Graph.input(1, :video),
          FFix.Graph.input(1, :audio)
        ],
        n: 2,
        v: 1,
        a: 1
      )

    assert video.media == :video
    assert audio.media == :audio
  end

  test "shape/2 reshapes ambiguous filter outputs" do
    outputs =
      FFix.Graph.input(0, :audio)
      |> Filter.ebur128(video: true)
      |> FFix.shape([:audio, :video])

    assert [audio, video] = outputs
    assert audio.media == :audio
    assert video.media == :video
  end

  test "normalizes enum-like values while keeping raw strings as an escape hatch" do
    video = FFix.Graph.input(0, :video)

    graph =
      video
      |> Filter.fade(type: :out, start_frame: "0", nb_frames: "30")
      |> then(&FFix.graph(output: &1))

    assert filter_node(graph, :fade).args == [type: "out", start_frame: 0, nb_frames: 30]

    assert FFix.to_filtergraph(graph) == "[0:v]fade=type=out:start_frame=0:nb_frames=30[out0];"

    raw_graph =
      video
      |> Filter.fade(type: "custom", start_frame: "0", nb_frames: "30")
      |> then(&FFix.graph(output: &1))

    assert filter_node(raw_graph, :fade).args == [type: "custom", start_frame: 0, nb_frames: 30]

    assert FFix.to_filtergraph(raw_graph) ==
             "[0:v]fade=type=custom:start_frame=0:nb_frames=30[out0];"
  end

  test "normalizes flag lists but keeps raw flag strings and numeric values" do
    video = FFix.Graph.input(0, :video)

    graph =
      video
      |> Filter.drawtext(text: "hi", x: 0, y: 0, text_align: [:center, :top])
      |> then(&FFix.graph(output: &1))

    assert filter_node(graph, :drawtext).args == [
             text: "hi",
             x: 0,
             y: 0,
             text_align: "center+top"
           ]

    assert FFix.to_filtergraph(graph) ==
             "[0:v]drawtext=text=hi:x=0:y=0:text_align=center+top[out0];"

    raw_graph =
      video
      |> Filter.drawtext(text: "hi", x: 0, y: 0, text_align: "C+T")
      |> then(&FFix.graph(output: &1))

    assert filter_node(raw_graph, :drawtext).args == [text: "hi", x: 0, y: 0, text_align: "C+T"]
    assert FFix.to_filtergraph(raw_graph) == "[0:v]drawtext=text=hi:x=0:y=0:text_align=C+T[out0];"

    numeric_graph =
      video
      |> Filter.drawtext(text: "hi", x: 0, y: 0, text_align: "3")
      |> then(&FFix.graph(output: &1))

    assert filter_node(numeric_graph, :drawtext).args == [text: "hi", x: 0, y: 0, text_align: 3]

    assert FFix.to_filtergraph(numeric_graph) ==
             "[0:v]drawtext=text=hi:x=0:y=0:text_align=3[out0];"
  end

  test "accepts implicit timeline enable options" do
    video = FFix.Graph.input(0, :video)

    graph =
      video
      |> Filter.drawtext(text: "hi", x: 0, y: 0, enable: FFix.expr("between(t,10,20)"))
      |> then(&FFix.graph(output: &1))

    assert FFix.to_filtergraph(graph) ==
             "[0:v]drawtext=text=hi:x=0:y=0:enable=between(t\\,10\\,20)[out0];"
  end

  test "accepts implicit framesync options" do
    video = FFix.Graph.input(0, :video)
    overlay = FFix.Graph.input(1, :video)

    graph =
      video
      |> Filter.overlay(overlay,
        x: 0,
        y: 0,
        eof_action: :pass,
        shortest: true,
        repeatlast: false,
        ts_sync_mode: :nearest
      )
      |> then(&FFix.graph(output: &1))

    assert FFix.to_filtergraph(graph) ==
             "[0:v][1:v]overlay=x=0:y=0:eof_action=pass:shortest=true:repeatlast=false:ts_sync_mode=nearest[out0];"
  end

  defp filter_node(%Graph{} = graph, name) do
    Enum.find(Graph.nodes(graph), &(&1.kind == :filter and &1.name == name))
  end
end
