defmodule FFix.Graph.EscapingTest do
  use ExUnit.Case, async: true

  alias FFix.Filter
  alias FFix.Graph
  alias FFix.Graph.Render
  alias FFix.Parsers.FilterGraph

  @texts [
    "hello",
    "hello:world",
    "it's ok",
    "back\\slash",
    "hello, world",
    "hello;world",
    "a[b]",
    " leading",
    "trailing ",
    " both ",
    "\t tabs\t ",
    "line\nbreak",
    "a=b|c",
    "literal %{not_an_expansion}",
    " :it's\\[,] ; \nnext "
  ]

  @ffmpeg (case File.regular?("/usr/bin/ffmpeg") do
             true -> "/usr/bin/ffmpeg"
             false -> System.find_executable("ffmpeg")
           end)
  @ffmpeg_skip (case @ffmpeg do
                  nil ->
                    "ffmpeg is required for escaping integration tests"

                  executable ->
                    {filters, status} =
                      System.cmd(executable, ["-hide_banner", "-filters"], stderr_to_stdout: true)

                    case status == 0 and String.contains?(filters, " drawtext ") and
                           String.contains?(filters, " scale ") do
                      true -> false
                      false -> "ffmpeg drawtext and scale filters are required"
                    end
                end)

  test "named and generic filters share two-layer literal encoding" do
    for text <- @texts ++ ["trailing\n"] do
      named = text_graph([text: text], :named)
      generic = text_graph([text: text], :generic)
      rendered = FFix.to_filtergraph(named)
      assert FFix.to_filtergraph(generic) == rendered

      [{:chain, [filter]}] = FilterGraph.parse(rendered)
      args = FilterGraph.parse_args(filter.args)
      assert {"text", text} in args

      # Reconstruct the explicit node data from the pure syntax parser.
      nodes =
        Map.new(named.nodes, fn {node_id, node} ->
          case node.kind do
            :filter -> {node_id, %{node | args: args}}
            :input -> {node_id, node}
          end
        end)

      assert FFix.to_filtergraph(%{named | nodes: nodes}) == rendered
    end
  end

  test "expression strings round-trip through boundary encoding" do
    expression = "if(gt(iw,32),32,iw)"
    video = Graph.input(0, :video)
    plain = video |> Filter.scale(w: expression, h: 32) |> then(&FFix.graph(output: &1))

    [{:chain, [filter]}] = plain |> FFix.to_filtergraph() |> FilterGraph.parse()
    assert FilterGraph.parse_args(filter.args) == [{"w", expression}, {"h", "32"}]
  end

  test "unsafe logical export names cannot inject graph syntax" do
    video = Graph.input(0, :video)
    [first, second, third] = Filter.split(video, outputs: 3)

    graph =
      FFix.graph(outputs: [{:"bad];null[evil", first}, {:out0, second}, {:simple_name, third}])

    result = Render.render(graph)
    assert Enum.map(result.exports, & &1.name) == [:"bad];null[evil", :out0, :simple_name]
    assert Enum.map(result.exports, & &1.label) == ["out0", "out0_1", "simple_name"]

    assert [{:chain, [%{outputs: ["out0", "out0_1", "simple_name"]}]}] =
             FilterGraph.parse(result.graph)
  end

  test "renderer rejects NUL in named values and expressions" do
    for value <- ["bad\0text", "bad\0expression"] do
      assert_raise ArgumentError, ~r/NUL/, fn ->
        [text: value] |> text_graph(:named) |> FFix.to_filtergraph()
      end
    end
  end

  @tag skip: @ffmpeg_skip
  test "literal drawtext matches textfile frame hashes in FFmpeg" do
    directory =
      Path.join(System.tmp_dir!(), "ffix-escaping-#{System.unique_integer([:positive])}")

    File.mkdir!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)

    for {text, index} <- Enum.with_index(@texts) do
      textfile = Path.join(directory, "text-#{index}.txt")
      File.write!(textfile, text)
      reference = [textfile: textfile] |> text_graph(:named) |> FFix.to_filtergraph()
      expected_hash = frame_hash(reference)

      for path <- [:named, :generic] do
        actual = [text: text] |> text_graph(path) |> FFix.to_filtergraph()

        assert frame_hash(actual) == expected_hash,
               "literal mismatch for #{inspect(text)} (#{path})"
      end
    end
  end

  @tag skip: @ffmpeg_skip
  test "escaped expressions produce the expected frames in FFmpeg" do
    video = Graph.input(0, :video)

    expected =
      video
      |> Filter.scale(w: 32, h: 32)
      |> then(&FFix.graph(output: &1))
      |> FFix.to_filtergraph()

    for width <- ["if(gt(iw,32),32,iw)", "min(iw,32)"] do
      actual =
        video
        |> Filter.scale(w: width, h: 32)
        |> then(&FFix.graph(output: &1))
        |> FFix.to_filtergraph()

      assert frame_hash(actual) == frame_hash(expected)
    end
  end

  defp text_graph(options, path) do
    video = Graph.input(0, :video)
    options = options ++ [fontsize: 24, fontcolor: :white, x: 8, y: 8, expansion: :none]

    stream =
      case path do
        :named -> Filter.drawtext(video, options)
        :generic -> FFix.filter(video, :drawtext, [:video], options)
      end

    FFix.graph(output: stream)
  end

  defp frame_hash(graph) do
    {output, status} =
      System.cmd(
        @ffmpeg,
        [
          "-hide_banner",
          "-nostdin",
          "-v",
          "error",
          "-f",
          "lavfi",
          "-i",
          "testsrc2=s=320x96:r=1:d=1",
          "-filter_complex",
          graph,
          "-map",
          "[out0]",
          "-frames:v",
          "1",
          "-threads",
          "1",
          "-f",
          "md5",
          "-"
        ],
        stderr_to_stdout: true
      )

    assert status == 0, "FFmpeg failed for #{inspect(graph)}:\n#{output}"
    assert String.match?(String.trim(output), ~r/\AMD5=[a-f0-9]{32}\z/)
    String.trim(output)
  end
end
