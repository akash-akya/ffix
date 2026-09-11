defmodule FFix.FunctionAPITest do
  use ExUnit.Case, async: true

  defmodule Example do
    use FFix

    def variants(video) do
      FFix.graph(
        outputs: [
          master: video |> scale(w: 1280, h: -1),
          preview: video |> scale(w: 320, h: -1) |> fps(fps: 1)
        ]
      )
    end

    def inline_command do
      command(
        [
          src: input("input.mp4", ss: "00:00:03"),
          music: input("music.mp3")
        ],
        fn inputs ->
          [
            master: inputs[:src][:video] |> scale(w: 1280, h: -1),
            preview: inputs[:src][:video] |> scale(w: 320, h: -1) |> fps(fps: 1)
          ]
        end,
        fn [master: master, preview: preview], inputs ->
          [
            output([master, inputs[:src][:audio]], "master.mp4",
              vcodec: :libx264,
              acodec: :aac
            ),
            output([preview], "thumb-%03d.jpg", f: :image2, vsync: 0),
            output([inputs[:src][audio: 0], inputs[:music][:audio]], "podcast.mka", acodec: :copy)
          ]
        end
      )
    end

    def graph_value_command do
      command(
        [
          src: input("input.mp4")
        ],
        fn inputs ->
          variants(inputs[:src][:video])
        end,
        fn graph, inputs ->
          [
            output([graph[:master], inputs[:src][:audio]], "master.mp4",
              vcodec: :libx264,
              acodec: :aac
            ),
            output([graph[:preview]], "thumb-%03d.jpg", f: :image2, vsync: 0)
          ]
        end
      )
    end

    def sources_output_command do
      command(
        [
          src: input("input.mp4")
        ],
        fn inputs ->
          [
            preview: inputs[:src][:video] |> scale(w: 320, h: -1)
          ]
        end,
        fn [preview: preview], inputs ->
          [
            output(
              [preview, inputs[:src][:audio]],
              "preview.mkv",
              vcodec: :libx264,
              acodec: :copy
            )
          ]
        end
      )
    end

    def graph_only_output_command do
      command(
        [
          src: input("input.mp4")
        ],
        fn inputs ->
          [
            preview: inputs[:src][:video] |> scale(w: 320, h: -1)
          ]
        end,
        fn [preview: preview] ->
          output([preview], "thumb-%03d.jpg", f: :image2, vsync: 0)
        end
      )
    end

    def graph_export_named_outputs_command do
      command(
        [
          src: input("input.mp4")
        ],
        fn inputs ->
          [
            outputs: inputs[:src][:video]
          ]
        end,
        fn [outputs: outputs] ->
          output([outputs], "out.mp4", vcodec: :copy)
        end
      )
    end
  end

  test "builds commands from graph and output callbacks" do
    assert FFix.to_argv(Example.inline_command()) == [
             "ffmpeg",
             "-ss",
             "00:00:03",
             "-i",
             "input.mp4",
             "-i",
             "music.mp3",
             "-filter_complex",
             "[0:v]scale=w=1280:h=-1[master];\n[0:v]scale=w=320:h=-1[scale_1_0];\n[scale_1_0]fps=fps=1[preview];",
             "-map",
             "[master]",
             "-map",
             "0:a",
             "-vcodec",
             "libx264",
             "-acodec",
             "aac",
             "master.mp4",
             "-map",
             "[preview]",
             "-f",
             "image2",
             "-vsync",
             "0",
             "thumb-%03d.jpg",
             "-map",
             "0:a:0",
             "-map",
             "1:a",
             "-acodec",
             "copy",
             "podcast.mka"
           ]
  end

  test "accepts a graph struct from the graph callback" do
    assert FFix.to_argv(Example.graph_value_command()) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-filter_complex",
             "[0:v]scale=w=1280:h=-1[master];\n[0:v]scale=w=320:h=-1[scale_1_0];\n[scale_1_0]fps=fps=1[preview];",
             "-map",
             "[master]",
             "-map",
             "0:a",
             "-vcodec",
             "libx264",
             "-acodec",
             "aac",
             "master.mp4",
             "-map",
             "[preview]",
             "-f",
             "image2",
             "-vsync",
             "0",
             "thumb-%03d.jpg"
           ]
  end

  test "supports low-level sources fallback in outputs" do
    assert FFix.to_argv(Example.sources_output_command()) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-filter_complex",
             "[0:v]scale=w=320:h=-1[preview];",
             "-map",
             "[preview]",
             "-map",
             "0:a",
             "-vcodec",
             "libx264",
             "-acodec",
             "copy",
             "preview.mkv"
           ]
  end

  test "passes graph values directly to one-arity output callbacks" do
    assert FFix.to_argv(Example.graph_only_output_command()) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-filter_complex",
             "[0:v]scale=w=320:h=-1[preview];",
             "-map",
             "[preview]",
             "-f",
             "image2",
             "-vsync",
             "0",
             "thumb-%03d.jpg"
           ]
  end

  test "treats graph callback keyword returns as exports" do
    assert FFix.to_argv(Example.graph_export_named_outputs_command()) == [
             "ffmpeg",
             "-i",
             "input.mp4",
             "-map",
             "0:v",
             "-vcodec",
             "copy",
             "out.mp4"
           ]
  end

  test "output sources preserve order without media grouping" do
    source = FFix.input("input.mp4")
    sound = FFix.audio(source)
    picture = FFix.video(source)
    sources = [{:sound, sound}, picture, {:main, picture}]
    output = FFix.output(sources, "out.mp4", t: 2)

    assert Enum.map(output.mappings, & &1.source) == [sound, picture, picture]
    assert Enum.map(output.mappings, & &1.name) == [:sound, nil, :main]
    assert output == FFix.Command.output(sources, "out.mp4", t: 2)
    assert output.options == [t: 2]
  end

  test "output accepts a single source, mapping, or named binding" do
    source = FFix.input("input.mp4") |> FFix.video()
    mapping = FFix.stream_copy(source)

    assert source |> FFix.output("out.mp4") |> Map.fetch!(:mappings) ==
             [FFix.Command.Mapping.new(source)]

    assert mapping |> FFix.output("out.mp4") |> Map.fetch!(:mappings) == [mapping]

    assert {:main, mapping} |> FFix.output("out.mp4") |> Map.fetch!(:mappings) ==
             [%{mapping | name: :main}]
  end

  test "output requires nonempty sources and rejects the old target-first forms" do
    for constructor <- [&FFix.output/2, &FFix.Command.output/2] do
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

  test "appending outputs uses sources before targets with only options defaulted" do
    source = FFix.input("input.mp4", ss: 1)
    picture = FFix.video(source)
    sound = FFix.audio(source)

    command =
      FFix.Command.new(inputs: [source])
      |> FFix.Command.output(picture, "video.mp4")
      |> FFix.Command.output(sound, "audio.mka", t: 2)

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

  test "rejects direct keyword graph specs in commands" do
    error =
      assert_raise ArgumentError, fn ->
        FFix.command(
          inputs: [src: FFix.input("input.mp4")],
          graph: [video: FFix.Graph.input(0, :video)],
          outputs: fn graph ->
            FFix.output([graph.video], "out.mp4", vcodec: :copy)
          end
        )
      end

    assert Exception.message(error) =~
             "command graph must be a %FFix.Graph{} or one-arity callback"
  end
end
