defmodule FFix.FunctionAPITest do
  use ExUnit.Case, async: true

  defmodule Example do
    import FFix, only: [input: 1, input: 2, output: 3, command: 1, video: 2, audio: 2]
    import FFix.Filter

    def variants(video) do
      FFix.graph(
        outputs: [
          master: scale(video, w: 1280, h: -1),
          preview: video |> scale(w: 320, h: -1) |> fps(fps: 1)
        ]
      )
    end

    def inline_command do
      source = input("input.mp4", ss: "00:00:03")
      music = input("music.mp3")
      graph = variants(video(source, 0))

      command([
        output([graph[:master], audio(source, 0)], "master.mp4", vcodec: :libx264, acodec: :aac),
        output(graph[:preview], "thumb-%03d.jpg", f: :image2, vsync: 0),
        output([audio(source, 0), audio(music, 0)], "podcast.mka", acodec: :copy)
      ])
    end

    def graph_value_command do
      source = input("input.mp4")
      graph = variants(video(source, 0))

      command([
        output([graph[:master], audio(source, 0)], "master.mp4", vcodec: :libx264, acodec: :aac),
        output(graph[:preview], "thumb-%03d.jpg", f: :image2, vsync: 0)
      ])
    end

    def sources_output_command do
      source = input("input.mp4")
      graph = FFix.graph(outputs: [preview: scale(video(source, 0), w: 320, h: -1)])

      command(
        output([graph[:preview], audio(source, 0)], "preview.mkv",
          vcodec: :libx264,
          acodec: :copy
        )
      )
    end

    def graph_only_output_command do
      source = input("input.mp4")
      graph = FFix.graph(outputs: [preview: scale(video(source, 0), w: 320, h: -1)])
      command(output(graph[:preview], "thumb-%03d.jpg", f: :image2, vsync: 0))
    end

    def graph_export_named_outputs_command do
      source = input("input.mp4")
      graph = FFix.graph(outputs: [outputs: video(source, 0)])
      command(output(graph[:outputs], "out.mp4", vcodec: :copy))
    end
  end

  test "ordinary selective imports compose multiple inputs and outputs" do
    assert FFix.to_argv(Example.inline_command()) == [
             "ffmpeg",
             "-ss",
             "00:00:03",
             "-i",
             "input.mp4",
             "-i",
             "music.mp3",
             "-filter_complex",
             "[0:v:0]scale=w=1280:h=-1[out0];\n[0:v:0]scale=w=320:h=-1[scale_1_0];\n[scale_1_0]fps=fps=1[out2];",
             "-map",
             "[out0]",
             "-map",
             "0:a:0",
             "-vcodec",
             "libx264",
             "-acodec",
             "aac",
             "master.mp4",
             "-map",
             "[out2]",
             "-f",
             "image2",
             "-vsync",
             "0",
             "thumb-%03d.jpg",
             "-map",
             "0:a:0",
             "-map",
             "1:a:0",
             "-acodec",
             "copy",
             "podcast.mka"
           ]
  end

  test "ordinary reusable functions return graph values" do
    assert FFix.to_argv(Example.graph_value_command()) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-filter_complex",
             "[0:v:0]scale=w=1280:h=-1[out0];\n[0:v:0]scale=w=320:h=-1[scale_1_0];\n[scale_1_0]fps=fps=1[out2];",
             "-map",
             "[out0]",
             "-map",
             "0:a:0",
             "-vcodec",
             "libx264",
             "-acodec",
             "aac",
             "master.mp4",
             "-map",
             "[out2]",
             "-f",
             "image2",
             "-vsync",
             "0",
             "thumb-%03d.jpg"
           ]
  end

  test "prebuilt graph exports compose with direct audio" do
    assert FFix.to_argv(Example.sources_output_command()) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-filter_complex",
             "[0:v:0]scale=w=320:h=-1[out0];",
             "-map",
             "[out0]",
             "-map",
             "0:a:0",
             "-vcodec",
             "libx264",
             "-acodec",
             "copy",
             "preview.mkv"
           ]
  end

  test "outputs can select only a graph export" do
    assert FFix.to_argv(Example.graph_only_output_command()) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-filter_complex",
             "[0:v:0]scale=w=320:h=-1[out0];",
             "-map",
             "[out0]",
             "-f",
             "image2",
             "-vsync",
             "0",
             "thumb-%03d.jpg"
           ]
  end

  test "outputs is an ordinary graph export name" do
    assert FFix.to_argv(Example.graph_export_named_outputs_command()) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-map",
             "0:v:0",
             "-vcodec",
             "copy",
             "out.mp4"
           ]
  end

  test "output sources preserve order without media grouping" do
    source = FFix.input("input.mp4")
    sound = FFix.audio(source, 0)
    picture = FFix.video(source, 0)
    sources = [{:sound, sound}, picture, {:main, picture}]
    output = FFix.output(sources, "out.mp4", t: 2)
    assert Enum.map(output.mappings, & &1.source) == [sound, picture, picture]
    assert Enum.map(output.mappings, & &1.name) == [:sound, nil, :main]
    assert output == FFix.Command.Output.new(sources, "out.mp4", t: 2)
    assert output.options == [t: 2]
  end

  test "output accepts a single source, mapping, or named binding" do
    source = FFix.input("input.mp4") |> FFix.video(0)
    mapping = FFix.stream_copy(source)

    assert source |> FFix.output("out.mp4") |> Map.fetch!(:mappings) == [
             FFix.Command.Mapping.new(source)
           ]

    assert mapping |> FFix.output("out.mp4") |> Map.fetch!(:mappings) == [mapping]

    assert {:main, mapping} |> FFix.output("out.mp4") |> Map.fetch!(:mappings) == [
             %{mapping | name: :main}
           ]
  end

  test "output requires nonempty sources and rejects the old target-first forms" do
    for constructor <- [&FFix.output/2, &FFix.Command.Output.new/2] do
      for sources <- [[], nil] do
        assert_raise ArgumentError, "output requires at least one source", fn ->
          constructor.(sources, "out.mp4")
        end
      end

      for old_sources <- [[:preview], [video: :preview], [sources: [:preview]]] do
        assert_raise ArgumentError, ~r/invalid output source\/target/, fn ->
          constructor.("out.mp4", old_sources)
        end
      end
    end
  end

  test "append operations accept existing declarations" do
    source = FFix.input("input.mp4", ss: 1)
    picture = FFix.video(source, 0)
    sound = FFix.audio(source, 0)

    command =
      FFix.Command.new()
      |> FFix.Command.add_input(source)
      |> FFix.Command.add_output(FFix.output(picture, "video.mp4"))
      |> FFix.Command.add_output(FFix.output(sound, "audio.mka", t: 2))

    assert command.outputs == [
             FFix.output(picture, "video.mp4"),
             FFix.output(sound, "audio.mka", t: 2)
           ]

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-ss",
             "1",
             "-i",
             "input.mp4",
             "-map",
             "0:v:0",
             "video.mp4",
             "-map",
             "0:a:0",
             "-t",
             "2",
             "audio.mka"
           ]
  end

  test "output-first commands reject graph specs and callback options" do
    output = FFix.input("input.mp4") |> FFix.video(0) |> FFix.output("out.mp4")

    assert_raise ArgumentError, ~r/unknown command keys/, fn ->
      FFix.command(output, graph: [video: FFix.Graph.input(0, :video)])
    end

    assert_raise ArgumentError, fn ->
      FFix.command(output, fn _graph -> flunk("must not run") end)
    end
  end
end
