# FF

`FF` builds ffmpeg filtergraphs and commands as Elixir data.

Use it when you want to assemble filter pipelines programmatically without
hand-building `-filter_complex` and `-map` strings. The command stays inspectable
until you serialize it to argv or run it.

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
    inputs: [src: "input.mp4"],
    graph: fn inputs ->
      [cropped: inputs.src[:video] |> crop(w: 720, h: 720)]
    end,
    outputs: fn %{cropped: cropped}, %{inputs: inputs} ->
      output("square.mp4", video: cropped, audio: inputs.src[:audio])
    end
  )

FF.to_argv(cmd)
```

## Pipe An Image

```elixir
cmd =
  command(
    inputs: [image: input(:stdin, f: :image2pipe)],
    graph: fn inputs ->
      [scaled: inputs.image[:video] |> scale(w: 640, h: -1)]
    end,
    outputs: fn %{scaled: scaled} ->
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
cmd =
  command(
    inputs: [src: "input.mp4"],
    graph: fn inputs ->
      [
        inputs.src[:video]
        |> scale(w: 1080, h: 1920, force_original_aspect_ratio: :increase)
        |> crop(w: 1080, h: 1920)
        |> fps(fps: 30)
      ]
    end,
    outputs: fn graph, %{inputs: inputs} ->
      output("short.mp4", video: graph[0], audio: inputs.src[:audio])
    end
  )
```

## Run Or Inspect

```elixir
FF.to_argv(cmd)
FF.to_shell_string(cmd)
FF.run(cmd)
```

`FF.to_argv/1` is the canonical boundary. `FF.to_shell_string/1` is for logs and
debugging.

## More

Start with the `FF` module docs for command callbacks, graph return shapes, and
output mapping. See `FF.Graph` for graph construction and parsing, `FF.Filter`
for generated filter helpers, and `FF.Runner` for streaming execution events.
