# FF

`FF` builds ffmpeg filtergraphs and commands as Elixir data.

Use it when you want to assemble filter pipelines programmatically without
hand-building `-filter_complex` and `-map` strings. It acts as a small
translation layer from Elixir callbacks and data structures to ffmpeg argv; the
command stays inspectable until you serialize it or run it.

## Requirements

`ffmpeg` must be available when compiling the library. `FF` generates filter
helpers from local ffmpeg metadata at compile time, so generated functions match
the ffmpeg version in the build environment.

Set `FFMPEG_BIN=/path/to/ffmpeg` if the executable is not named `ffmpeg` or is
not on `PATH`.

## Installation

```elixir
def deps do
  [
    {:ff, "~> 0.1.0"}
  ]
end
```

Examples below assume:

```elixir
import FF
import FF.Filter
```

## Crop A Video

```elixir
cmd =
  command(
    "input.mp4",
    fn src ->
      src[:video] |> crop(w: 720, h: 720)
    end,
    fn cropped, src ->
      output("square.mp4", video: cropped, audio: src[:audio])
    end
  )

FF.to_argv(cmd)
```

## Pipe An Image

```elixir
cmd =
  command(
    input(:stdin, f: :image2pipe),
    fn image ->
      image[:video] |> scale(w: 640, h: -1)
    end,
    fn scaled ->
      output(:stdout, video: scaled, f: :image2pipe, vcodec: :png)
    end
  )

result =
  FF.run!(cmd,
    stdin: File.stream!("input.png", [], 2048),
    stdout: :collect
  )

File.write!("small.png", result.stdout)
```

## Vertical Short

```elixir
command(
  "input.mp4",
  fn src ->
    src[:video]
    |> scale(w: 1080, h: 1920, force_original_aspect_ratio: :increase)
    |> crop(w: 1080, h: 1920)
    |> fps(fps: 30)
    |> drawtext(text: "Launch Day", x: expr("(w-tw)/2"), y: expr("(h-th)/2"))
  end,
  fn short, src ->
    output("short.mp4", video: short, audio: src[:audio])
  end
)
```

## Run Or Inspect

Command-level options are the final argument:

```elixir
command(
  "input.mp4",
  fn src -> src[:video] end,
  fn video -> output("copy.mp4", video: video, c: :copy) end,
  global: [y: true]
)
```

```elixir
FF.to_argv(cmd)
FF.to_shell_string(cmd)
FF.run(cmd)
```

`FF.to_argv/1` is the canonical boundary. `FF.to_shell_string/1` is for logs and
debugging.

## More

Start with the `FF` module docs for the command model, option placement, graph
return shapes, and output mapping. See `FF.Graph` for graph construction and
parsing, `FF.Filter` for generated filter helpers, and `FF.Runner` for
streaming execution events.
