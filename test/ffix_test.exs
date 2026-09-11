defmodule FFTest do
  use ExUnit.Case, async: true

  alias FFix.Filter
  alias FFix.Graph.Export

  test "builds and renders a single exported graph" do
    video =
      FFix.Graph.input(0, :video)
      |> Filter.scale(w: 1280, h: -1)
      |> Filter.drawtext(text: "Hello", x: "w-tw-20", y: 20)

    graph = FFix.graph(output: video)

    assert [%Export{name: nil}] = graph.exports

    assert FFix.to_filtergraph(graph) ==
             """
             [0:v]scale=w=1280:h=-1[scale_0];
             [scale_0]drawtext=text=Hello:x=w-tw-20:y=20[out0];
             """
             |> String.trim()
  end

  test "builds a graph with multiple exported outputs" do
    video = FFix.Graph.input(0, :video)
    [master, preview] = Filter.split(video, outputs: 2)

    preview =
      preview
      |> Filter.fps(fps: 1)
      |> Filter.scale(w: 320, h: -1)

    graph = FFix.graph(outputs: [master: master, preview: preview])

    assert Enum.map(graph.exports, & &1.name) == [:master, :preview]

    assert FFix.to_filtergraph(graph) ==
             """
             [0:v]split=outputs=2[master][split_1];
             [split_1]fps=fps=1[fps_0];
             [fps_0]scale=w=320:h=-1[preview];
             """
             |> String.trim()
  end
end
