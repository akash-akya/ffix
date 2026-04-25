Mix.Task.run("app.start")

import FF
import FF.Filter

input_path = "test/support/sample.mp4"
output_path = "tmp/vertical_short.mp4"

File.exists?(input_path) || raise "missing #{input_path}"
System.find_executable("ffprobe") || raise "ffprobe must be available on PATH"

File.mkdir_p!(Path.dirname(output_path))

cmd =
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

IO.puts(FF.to_shell_string(cmd))
FF.run!(cmd, stderr: :collect)

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
dimensions == "1080x1920" || raise "expected 1080x1920, got #{inspect(dimensions)}"

size = File.stat!(output_path).size
IO.puts("wrote #{output_path} (#{size} bytes, #{dimensions})")
