defmodule FFix.Filter.GenericTest do
  use ExUnit.Case, async: true

  alias FFix.{Encoder, Filter, Graph, Muxer}
  alias FFix.Graph.Terminal

  test "unknown names and options serialize without creating atoms" do
    name = "vendor_filter_#{System.unique_integer([:positive])}"
    assert_raise ArgumentError, fn -> String.to_existing_atom(name) end
    result = Filter.filter(Graph.input(0, :video), name, [:video], [{"custom-option", 5}])
    assert render(result) == "[0:v]#{name}=custom-option=5[out0];"
    assert_raise ArgumentError, fn -> String.to_existing_atom(name) end
  end

  test "known names do not enable schemas, shape inference, or emitted defaults" do
    video = Graph.input(0, :video)
    result = Filter.filter(video, "scale", [:audio], future: :value)
    assert result.media == :audio
    assert render(result) == "[0:v]scale=future=value[out0];"

    assert_raise ArgumentError, ~r/is not a valid option/, fn ->
      Filter.scale(video, future: :value)
    end

    [first, second] = Filter.filter(video, "split", [:video, :video])
    assert FFix.to_filtergraph(FFix.graph(outputs: [first, second])) == "[0:v]split[out0][out1];"
  end

  test "source and sink filters use explicit empty input and output lists" do
    source = Filter.filter([], "vendor_source", [:audio], frequency: 440)
    assert render(source) == "vendor_source=frequency=440[out0];"
    terminal = Filter.filter(source, "vendor_sink", [])
    assert %Terminal{} = terminal
    graph = FFix.graph(terminals: [terminal])

    assert FFix.to_filtergraph(graph) ==
             "vendor_source=frequency=440[vendor_source_0];\n[vendor_source_0]vendor_sink;"
  end

  test "input and output collections preserve order and individual media" do
    inputs = [Graph.input(0, :audio), Graph.input(1, :video)]
    [sound, picture, unknown] = Filter.filter(inputs, "vendor_mixed", [:audio, :video, :unknown])
    assert Enum.map([sound, picture, unknown], & &1.media) == [:audio, :video, :unknown]
    graph = FFix.graph(outputs: [picture: picture, sound: sound, other: unknown])
    assert FFix.to_filtergraph(graph) == "[0:a][1:v]vendor_mixed[sound][picture][other];"
    assert Enum.map(graph.exports, & &1.media) == [:video, :audio, :unknown]
  end

  test "generic output media reaches encoders, muxers, and output callbacks" do
    source = FFix.input("in.mp4")
    [picture, sound] = Filter.filter(FFix.video(source, 0), "vendor_mixed", [:video, :audio])

    command =
      FFix.command(
        Muxer.matroska([sound: Encoder.aac(sound), picture: Encoder.libx264(picture)], "out.mkv",
          output_options: [
            metadata: fn output_streams ->
              assert output_streams == %{
                       sound: %{index: 0, specifier: "a:0"},
                       picture: %{index: 1, specifier: "v:0"}
                     }

              "title=mixed"
            end
          ]
        )
      )

    assert "title=mixed" in FFix.to_argv(command)
  end

  test "generic values preserve expressions, positional arguments, and boundary escaping" do
    text = ~S(a:b,c;[d]'e\f)
    expression = "if(gt(iw,320),320,iw)"

    result =
      Filter.filter([], "vendor", [:video], [
        {:pos, text},
        {:pos, 2},
        {:enabled, false},
        {"width", expression},
        mode: :fast
      ])

    assert [chain: [parsed]] = FFix.Parsers.FilterGraph.parse(render(result))

    assert FFix.Parsers.FilterGraph.parse_args(parsed.args) == [
             {:pos, text},
             {:pos, "2"},
             {"enabled", "false"},
             {"width", expression},
             {"mode", "fast"}
           ]
  end

  test "mixed generic and named filters use deterministic collision-free labels" do
    result =
      Graph.input(0, :video)
      |> Filter.filter("scale", [:video], w: 320, h: -2)
      |> Filter.scale(w: 160, h: -2)
      |> Filter.filter("null", [:video])

    rendered = render(result)

    assert rendered ==
             "[0:v]scale=w=320:h=-2[scale_0];\n" <>
               "[scale_0]scale=w=160:h=-2[scale_1_0];\n[scale_1_0]null[out0];"

    assert rendered == FFix.to_filtergraph(Graph.parse!(rendered))

    assert_raise ArgumentError, ~r/unknown filter/, fn ->
      Graph.parse!("[0:v]vendor_filter[out]")
    end
  end

  test "structural validation rejects invalid inputs, shapes, names, and values" do
    video = Graph.input(0, :video)

    for inputs <- [nil, :video, "input.mp4", %{}, [video, []], [video, :wrong]] do
      assert_raise ArgumentError, fn -> Filter.filter(inputs, "scale", [:video]) end
    end

    for shape <- [nil, :video, 1, [:subtitle], [[:video]], [nil]] do
      assert_raise ArgumentError, fn -> Filter.filter(video, "scale", shape) end
    end

    for name <- [nil, false, "", "scale,negate", "scale@instance", "has space", "bad\n", "bad\0"] do
      assert_raise ArgumentError, ~r/filter name must be/, fn ->
        Filter.filter(video, name, [:video])
      end
    end

    for options <- [nil, %{}, [:bad], [{"bad:key", 1}], [foo: 1, foo: 2], [{:foo, 1}, {"foo", 2}]] do
      assert_raise ArgumentError, fn -> Filter.filter(video, "vendor", [:video], options) end
    end

    for value <- [nil, %{}, [:fast], fn -> 1 end, fn _streams -> 1 end, %{source: 1}, "bad\0"] do
      assert_raise ArgumentError, fn ->
        Filter.filter(video, "vendor", [:video], custom: value)
      end
    end

    [kept, _unused] = Filter.filter(video, "vendor", [:video, :audio])
    assert_raise ArgumentError, ~r/unconnected filter output/, fn -> render(kept) end
  end

  defp render(result) do
    result |> then(&FFix.graph(output: &1)) |> FFix.to_filtergraph()
  end
end
