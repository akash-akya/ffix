Mix.Task.run("app.start")

import FF
import FF.Filter

root = File.cwd!()
input_path = Path.join(root, "test/support/sample.mp4")
output_path = Path.join(root, "tmp/vertical_short.mp4")

unless File.exists?(input_path) do
  raise """
  expected sample video at #{input_path}

  Add a local sample fixture at test/support/sample.mp4 before running this script.
  """
end

unless System.find_executable("ffprobe") do
  raise "ffprobe is required to verify the generated video"
end

File.mkdir_p!(Path.dirname(output_path))

command =
  command(
    input(input_path, t: 3),
    fn src ->
      src[:video]
      |> scale(w: 1080, h: 1920, force_original_aspect_ratio: :increase)
      |> crop(w: 1080, h: 1920)
      |> fps(fps: 30)
      |> drawtext(text: "Launch Day", x: expr("(w-tw)/2"), y: expr("(h-th)/2"))
    end,
    fn short, src ->
      output(output_path,
        video: short,
        audio: src[:audio],
        vcodec: :mpeg4,
        acodec: :aac,
        shortest: true
      )
    end,
    global: [y: true, hide_banner: true, loglevel: :error]
  )

IO.puts(FF.to_shell_string(command))

FF.run!(command, stderr: :collect)

{dimensions, 0} =
  System.cmd("ffprobe", [
    "-v",
    "error",
    "-select_streams",
    "v:0",
    "-show_entries",
    "stream=width,height",
    "-of",
    "csv=p=0:s=x",
    output_path
  ])

dimensions = String.trim(dimensions)

unless dimensions == "1080x1920" do
  raise "expected 1080x1920 output, got #{inspect(dimensions)}"
end

size = File.stat!(output_path).size

IO.puts("wrote #{Path.relative_to_cwd(output_path)} (#{size} bytes, #{dimensions})")
