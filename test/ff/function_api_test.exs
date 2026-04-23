defmodule FF.FunctionAPITest do
  use ExUnit.Case, async: true

  defmodule Example do
    use FF

    def variants(video) do
      FF.graph(
        outputs: [
          master: video |> scale(w: 1280, h: -1),
          preview: video |> scale(w: 320, h: -1) |> fps(fps: 1)
        ]
      )
    end

    def inline_command do
      command(
        inputs: [
          src: input("input.mp4", ss: "00:00:03"),
          music: input("music.mp3")
        ],
        graph: fn inputs ->
          [
            master: inputs.src[:video] |> scale(w: 1280, h: -1),
            preview: inputs.src[:video] |> scale(w: 320, h: -1) |> fps(fps: 1)
          ]
        end,
        outputs: fn graph, %{inputs: inputs} ->
          [
            output("master.mp4",
              video: graph.master,
              audio: inputs.src[:audio],
              vcodec: :libx264,
              acodec: :aac
            ),
            output("thumb-%03d.jpg", video: graph.preview, f: :image2, vsync: 0),
            output("podcast.mka",
              audio: [inputs.src[audio: 0], inputs.music[:audio]],
              acodec: :copy
            )
          ]
        end
      )
    end

    def graph_value_command do
      command(
        inputs: [
          src: input("input.mp4")
        ],
        graph: fn inputs ->
          variants(inputs.src[:video])
        end,
        outputs: fn graph, %{inputs: inputs} ->
          [
            output("master.mp4",
              video: graph.master,
              audio: inputs.src[:audio],
              vcodec: :libx264,
              acodec: :aac
            ),
            output("thumb-%03d.jpg", video: graph.preview, f: :image2, vsync: 0)
          ]
        end
      )
    end

    def sources_output_command do
      command(
        inputs: [
          src: input("input.mp4")
        ],
        graph: fn inputs ->
          [
            preview: inputs.src[:video] |> scale(w: 320, h: -1)
          ]
        end,
        outputs: fn graph, %{inputs: inputs} ->
          [
            output("preview.mkv",
              sources: [graph.preview, inputs.src[:audio]],
              vcodec: :libx264,
              acodec: :copy
            )
          ]
        end
      )
    end

    def graph_only_output_command do
      command(
        inputs: [
          src: input("input.mp4")
        ],
        graph: fn inputs ->
          [
            preview: inputs.src[:video] |> scale(w: 320, h: -1)
          ]
        end,
        outputs: fn graph ->
          output("thumb-%03d.jpg", video: graph.preview, f: :image2, vsync: 0)
        end
      )
    end

    def graph_export_named_outputs_command do
      command(
        inputs: [
          src: input("input.mp4")
        ],
        graph: fn inputs ->
          [
            outputs: inputs.src[:video]
          ]
        end,
        outputs: fn graph ->
          output("out.mp4", video: graph.outputs, vcodec: :copy)
        end
      )
    end
  end

  test "builds commands from graph and output callbacks" do
    assert FF.to_argv(Example.inline_command()) == [
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
    assert FF.to_argv(Example.graph_value_command()) == [
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
    assert FF.to_argv(Example.sources_output_command()) == [
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
    assert FF.to_argv(Example.graph_only_output_command()) == [
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
    assert FF.to_argv(Example.graph_export_named_outputs_command()) == [
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

  test "rejects mixing role outputs with sources" do
    assert_raise ArgumentError, "output/2 accepts either media roles or :sources, not both", fn ->
      FF.output("out.mp4", video: :preview, sources: [:audio])
    end
  end

  test "rejects output/2 source lists" do
    assert_raise ArgumentError,
                 "output/2 expects keyword options with :video, :audio, or :sources",
                 fn ->
                   FF.output("out.mp4", [:preview])
                 end
  end

  test "rejects unsupported output media roles" do
    assert_raise ArgumentError,
                 "unsupported output media roles: [:subtitle]; use :video, :audio, or :sources",
                 fn ->
                   FF.output("out.mkv", subtitle: :subtitles, c: :copy)
                 end
  end

  test "rejects direct keyword graph specs in commands" do
    error =
      assert_raise ArgumentError, fn ->
        FF.command(
          inputs: [src: FF.input("input.mp4")],
          graph: [video: FF.Graph.input(0, :video)],
          outputs: fn graph ->
            FF.output("out.mp4", video: graph.video, vcodec: :copy)
          end
        )
      end

    assert Exception.message(error) =~ "command graph must be a %FF.Graph{} or one-arity callback"
  end
end
