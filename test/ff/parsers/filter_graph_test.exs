defmodule FF.Parsers.FilterGraphTest do
  use ExUnit.Case, async: true

  alias FF.Parsers.FilterGraph

  test "parses settings, labels, instances, and raw args" do
    graph =
      "sws_flags=accurate_rnd+full_chroma_int; [0:v] drawtext@main = text='hello, world':x=20:y=20 [video]"

    assert [
             {:setting, "sws_flags", "accurate_rnd+full_chroma_int"},
             {:chain,
              [
                %{
                  inputs: ["0:v"],
                  name: "drawtext",
                  instance: "main",
                  args: "text='hello, world':x=20:y=20",
                  outputs: ["video"]
                }
              ]}
           ] = FilterGraph.parse(graph)
  end

  test "parses comma-separated chains with unlabeled filters" do
    graph = "testsrc,split[L1],hflip[L2];[L1][L2]hstack"

    assert [
             {:chain,
              [
                %{name: "testsrc", inputs: [], outputs: [], args: nil, instance: nil},
                %{name: "split", inputs: [], outputs: ["L1"], args: nil, instance: nil},
                %{name: "hflip", inputs: [], outputs: ["L2"], args: nil, instance: nil}
              ]},
             {:chain,
              [
                %{name: "hstack", inputs: ["L1", "L2"], outputs: [], args: nil, instance: nil}
              ]}
           ] = FilterGraph.parse(graph)
  end
end
