defmodule FF.DSLTest do
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
        graph: [
          master: src[:video] |> scale(w: 1280, h: -1),
          preview: src[:video] |> scale(w: 320, h: -1) |> fps(fps: 1)
        ],
        outputs: [
          output("master.mp4",
            video: :master,
            audio: src[:audio],
            vcodec: :libx264,
            acodec: :aac
          ),
          output("thumb-%03d.jpg", video: :preview, f: :image2, vsync: 0),
          output("podcast.mka", audio: [src[audio: 0], music[:audio]], acodec: :copy)
        ]
      )
    end

    def graph_value_command do
      command(
        inputs: [
          src: input("input.mp4")
        ],
        graph: variants(src[:video]),
        outputs: [
          output("master.mp4",
            video: :master,
            audio: src[:audio],
            vcodec: :libx264,
            acodec: :aac
          ),
          output("thumb-%03d.jpg", video: :preview, f: :image2, vsync: 0)
        ]
      )
    end

    def sources_output_command do
      command(
        inputs: [
          src: input("input.mp4")
        ],
        graph: [
          preview: src[:video] |> scale(w: 320, h: -1)
        ],
        outputs: [
          output("preview.mkv", sources: [:preview, src[:audio]], vcodec: :libx264, acodec: :copy)
        ]
      )
    end
  end

  test "builds commands from inline graph and role-based outputs" do
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

  test "accepts a graph struct expression in graph" do
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

  test "rejects mixing role outputs with sources" do
    assert_raise ArgumentError, "output/2 accepts either media roles or :sources, not both", fn ->
      defmodule InvalidOutput do
        use FF

        def command do
          command(
            inputs: [src: input("input.mp4")],
            graph: [preview: src[:video]],
            outputs: [output("out.mp4", video: :preview, sources: [src[:audio]])]
          )
        end
      end

      InvalidOutput.command()
    end
  end
end
