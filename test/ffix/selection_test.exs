defmodule FFix.SelectionTest do
  use ExUnit.Case, async: true

  alias FFix.{Command, Encoder, Filter, Graph, Muxer, Selection}
  alias FFix.Graph.StreamRef

  test "media helpers require an explicit index or :all" do
    input = FFix.input("not-opened.mkv")

    for helper <- [:video, :audio, :subtitle] do
      assert %StreamRef{} = apply(FFix, helper, [input, 0])
      assert %Selection{} = apply(FFix, helper, [input, :all])
      assert_raise ArgumentError, fn -> apply(FFix, helper, [input, -1]) end
    end

    assert %StreamRef{media: :unknown} = FFix.select(input, 3)
    assert %Selection{} = FFix.select(input, :all)
    assert %Selection{} = FFix.select(input, "v:0")

    for selector <- [{:video, 0}, {:raw, "v:0"}, :video, -1, "", "a\0"] do
      assert_raise ArgumentError, fn -> FFix.select(input, selector) end
    end
  end

  test "cover-art exclusion is typed and keeps video media" do
    input = FFix.input("in.mkv")
    picture = FFix.video(input, 0, attached_pictures: false)
    assert %StreamRef{media: :video} = picture
    assert %Selection{} = selection = FFix.video(input, :all, attached_pictures: false)
    assert Selection.media(selection) == :video

    command = picture |> FFix.stream_copy() |> FFix.output("out.mkv") |> FFix.command()
    assert "0:V:0" in FFix.to_argv(command)

    graph = Graph.parse!("[0:V:0]hflip[picture]")
    assert Graph.to_filtergraph(graph) == "[0:V:0]hflip[picture];"

    assert_raise ArgumentError, fn -> FFix.audio(input, 0, attached_pictures: false) end
    assert_raise ArgumentError, fn -> FFix.video(input, 0, attached_pictures: :no) end
  end

  test "optional selections are unresolved even for an exact index" do
    input = FFix.input("in.mkv")
    assert %Selection{} = optional = FFix.audio(input, 0, optional: true)
    assert %Selection{} = FFix.select(input, 3, optional: true)
    assert optional.input_ref.declaration == input
    assert Selection.media(optional) == :audio

    command = optional |> FFix.stream_copy() |> FFix.output("out.mkv") |> FFix.command()

    assert Enum.chunk_every(FFix.to_argv(command), 2, 1, :discard)
           |> Enum.member?(["-map", "0:a:0?"])

    assert_raise ArgumentError, fn -> FFix.audio(input, 0, optional: nil) end
    assert_raise ArgumentError, fn -> FFix.audio(input, 0, optional: true, optional: false) end
    assert_raise ArgumentError, fn -> FFix.select(input, :all, missing: :ignore) end
  end

  test "queries cannot feed filters, graph exports, or bound graph ports" do
    input = FFix.input("in.mkv")
    template = FFix.graph(output: Filter.hflip(Graph.input(:picture, :video)))

    for selection <- [
          FFix.video(input, :all),
          FFix.video(input, 0, optional: true),
          FFix.select(input, "v")
        ] do
      assert_raise ArgumentError, fn -> Filter.hflip(selection) end
      assert_raise ArgumentError, fn -> FFix.filter([selection], "hflip", [:video]) end
      assert_raise ArgumentError, fn -> FFix.graph(output: selection) end
      assert_raise ArgumentError, fn -> Graph.bind(template, picture: selection) end
      assert_raise Protocol.UndefinedError, fn -> Enum.to_list(selection) end
    end

    assert_raise ArgumentError, fn -> Graph.input(0, {:video, :all}) end
    graph_matcher = Graph.input(0, :video)
    assert %StreamRef{} = Filter.hflip(graph_matcher)

    assert_raise ArgumentError, ~r/graph input matchers/, fn ->
      graph_matcher |> FFix.output("out.mkv") |> FFix.command(inputs: [input])
    end
  end

  test "canonical graph validation also rejects broad selectors on a filter pad" do
    graph = Graph.parse!("[0:v]hflip[picture]")
    [input_node | _rest] = graph.order
    graph = update_in(graph.nodes[input_node].input_ref.selector, fn _ -> {:video, :all} end)

    assert_raise ArgumentError, ~r/graph inputs require one stream/, fn ->
      Graph.to_filtergraph(graph)
    end
  end

  test "optional raw selectors retain a single optional marker and remain opaque" do
    input = FFix.input("in.mkv")

    for raw <- ["a?", "v:0?"] do
      selection = FFix.select(input, raw, optional: true)
      assert Selection.media(selection) == :unknown
      command = selection |> FFix.stream_copy() |> FFix.output("out.mkv") |> FFix.command()
      assert ("0:" <> raw) in FFix.to_argv(command)
      refute ("0:" <> raw <> "?") in FFix.to_argv(command)
    end
  end

  test "all-copy queries remain direct mappings without fabricated graph pads" do
    input = FFix.input("in.mkv")

    Enum.each([{FFix.select(input, :all), "0"}, {FFix.audio(input, :all), "0:a"}], fn
      {selection, expected} ->
        command = selection |> FFix.stream_copy() |> Muxer.matroska("out.mkv") |> FFix.command()
        assert command.graph == nil
        assert command.inputs == [input]

        assert FFix.to_argv(command) == [
                 "ffmpeg",
                 "-i",
                 "in.mkv",
                 "-map",
                 expected,
                 "-c",
                 "copy",
                 "-f",
                 "matroska",
                 "out.mkv"
               ]
    end)
  end

  test "query dependencies preserve order alongside filtered sources" do
    sounds = FFix.input("same.mkv", ss: 1)
    pictures = FFix.input("same.mkv", ss: 2)

    output =
      FFix.output(
        [
          FFix.stream_copy(FFix.audio(sounds, :all)),
          Encoder.ffv1(Filter.hflip(FFix.video(pictures, 0)))
        ],
        "out.mkv"
      )

    command = FFix.command(output)
    assert command.inputs == [sounds, pictures]
    assert Enum.count(Graph.nodes(command.graph), &(&1.kind == :input)) == 1
    assert "0:a" in FFix.to_argv(command)
    assert Enum.any?(FFix.to_argv(command), &String.contains?(&1, "[1:v:0]hflip"))
    assert "1:a" in FFix.to_argv(FFix.command(output, inputs: [pictures, sounds]))
  end

  test "selection snapshots are checked in both constructors and across source types" do
    input = FFix.input("in.mkv")
    changed = %{input | options: [ss: 2]}
    query = FFix.audio(input, :all)
    output = FFix.output(query, "out.mkv")

    assert_raise ArgumentError, ~r/conflicting input snapshots/, fn ->
      FFix.command(output, inputs: [changed])
    end

    assert_raise ArgumentError, ~r/conflicting input snapshots/, fn ->
      Command.new(inputs: [changed], outputs: [output]) |> FFix.to_argv()
    end

    assert_raise ArgumentError, ~r/conflicting input snapshots/, fn ->
      FFix.command(FFix.output([query, FFix.video(changed, 0)], "out.mkv"))
    end

    assert_raise ArgumentError, ~r/missing from explicit/, fn ->
      FFix.command(output, inputs: [])
    end
  end

  test "uniform media scopes support mixed encoding without knowing selection counts" do
    input = FFix.input("in.mkv")

    output =
      FFix.output(
        [
          FFix.stream_copy(FFix.audio(input, :all)),
          Encoder.mpeg4(FFix.video(input, :all), b: "200k")
        ],
        "out.mkv"
      )

    assert FFix.to_argv(FFix.command(output)) == [
             "ffmpeg",
             "-i",
             "in.mkv",
             "-map",
             "0:a",
             "-map",
             "0:v",
             "-c:a",
             "copy",
             "-c:v",
             "mpeg4",
             "-b:v",
             "200k",
             "out.mkv"
           ]

    output =
      FFix.output(
        [
          FFix.stream_copy(FFix.audio(input, :all)),
          Encoder.mpeg4(FFix.video(input, 0), b: "200k"),
          Encoder.mpeg4(FFix.video(input, 0), b: "400k")
        ],
        "out.mkv"
      )

    argv = FFix.to_argv(FFix.command(output))
    assert Enum.chunk_every(argv, 2, 1, :discard) |> Enum.member?(["-b:v:0", "200k"])
    assert Enum.chunk_every(argv, 2, 1, :discard) |> Enum.member?(["-b:v:1", "400k"])
    refute "-b:1" in argv
  end

  test "ambiguous same-media scopes cannot silently override copy or defaults" do
    input = FFix.input("in.mkv")
    copied = FFix.stream_copy(FFix.audio(input, :all))

    for other <- [
          Encoder.aac(FFix.audio(input, 0)),
          FFix.audio(input, 0),
          Encoder.aac(FFix.audio(input, :all))
        ] do
      output = FFix.output([copied, other], "out.mkv")

      assert_raise ArgumentError, ~r/ambiguous output encoding/, fn -> FFix.command(output) end

      assert_raise ArgumentError, ~r/ambiguous output encoding/, fn ->
        Command.new(inputs: [input], outputs: [output]) |> FFix.to_argv()
      end
    end

    assert_raise ArgumentError, ~r/ambiguous output encoding/, fn ->
      FFix.command(
        FFix.output(
          [FFix.stream_copy(FFix.select(input, "a")), Encoder.ffv1(FFix.video(input, 0))],
          "out.mkv"
        )
      )
    end

    assert_raise ArgumentError, ~r/expects video/, fn ->
      Encoder.libx264(FFix.audio(input, :all))
    end
  end

  test "raw queries and optional indexes keep their literal mapping suffixes" do
    input = FFix.input("in.mkv")

    output =
      FFix.output(
        [FFix.select(input, "a:m:language:eng"), FFix.select(input, 4, optional: true)],
        "out.mkv",
        c: :copy
      )

    argv = FFix.command(output) |> FFix.to_argv()
    assert "0:a:m:language:eng" in argv
    assert "0:4?" in argv
    assert_raise ArgumentError, fn -> Selection.validate!(%Selection{input_ref: %{}}) end

    assert_raise ArgumentError, fn ->
      FFix.output(FFix.audio(input, :all), "out.mkv", c: :copy)
      |> Map.update!(:mappings, fn [mapping] -> [%{mapping | encoding: :copy}] end)
      |> FFix.command()
    end
  end
end
