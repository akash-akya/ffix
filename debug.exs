defmodule FFDebug do
  alias FF
  alias FF.Filter
  alias FF.Filter.Builder
  # alias FF.FilterGraph

  def graph(a, b) do
    b =
      b
      |> Filter.scale(w: "350", h: "-1")
      |> Filter.gblur(sigma: "2")

    a
    |> Filter.overlay(b,
      x: "main_w/2 - overlay_w/2",
      y: "main_h/2 - overlay_h/2"
    )
    |> Filter.drawtext(
      text: "Hello There!",
      # y_align: "baseline",
      x: "main_w/2 - text_w/2",
      y: "main_h/2 - text_h/2",
      fontsize: "200"
    )
    |> Filter.drawtext(
      text: "Booom",
      # y_align: "baseline",
      x: "500",
      y: "100",
      fontsize: "100"
    )
  end

  build_ffm(
    [file1, file2],
    fn [file1, file2] -> graph(file1[:video][0], file2[:video][1]) end,
    fn inputs, filtered -> encode(inputs, filtered) end
  )

  # build_command(
  #   inputs: [file1, file2],
  #   filter_graph: graph("0", "1"),
  #   outputs: [out1, out2]
  # )

  def stream(file1, file2) do
    a = Builder.source("0")
    b = Builder.source("1")

    FF.stream(graph(a, b), [file1, file2])
  end
end

FFDebug.stream(
  "/home/akash/Shared/repos/ff/test/support/bbb_sunflower_1080p_30fps_normal.mp4",
  "/home/akash/Shared/repos/ff/test/support/smiley.png"
  # "/home/akash/Shared/repos/ff/test/support/smiley.png"
)
|> Stream.into(File.stream!("out.mp4"))
|> Stream.run()
