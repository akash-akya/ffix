# FFix

[![Hex.pm](https://img.shields.io/hexpm/v/ffix.svg)](https://hex.pm/packages/ffix)
[![Documentation](https://img.shields.io/badge/docs-hexdocs.pm-blue.svg)](https://hexdocs.pm/ffix)
[![CI](https://github.com/akash-akya/ffix/actions/workflows/ci.yaml/badge.svg)](https://github.com/akash-akya/ffix/actions/workflows/ci.yaml)
[![License](https://img.shields.io/hexpm/l/ffix.svg)](https://github.com/akash-akya/ffix/blob/master/LICENSE)
[![Elixir](https://img.shields.io/badge/elixir-%7E%3E%201.16-4B275F.svg)](https://elixir-lang.org/)

`FFix` lets you build ffmpeg filtergraphs and commands without hand-assembling
command-line soup.

Use it when you want to assemble filter pipelines programmatically without
hand-building `-filter_complex` and `-map` strings. It is a thin Elixir layer
over ffmpeg: you build inputs, streams, filtergraphs, and outputs with Elixir
data and functions, then `FFix` turns them into ffmpeg argv.

It does not try to hide ffmpeg or replace ffmpeg knowledge with a separate
media-processing abstraction. Filter names, options, stream mappings, codecs,
muxers, and expressions are still ffmpeg concepts. The goal is to make those
pieces easier to compose, inspect, and run from Elixir.

## Filters

`FFix.Filter` exposes helpers for the filters reported by the local `ffmpeg`
executable at compile time. Use them like normal Elixir functions:
`scale/2`, `crop/2`, `overlay/3`, `drawtext/2`, `fps/2`, and so on.

The generated docs include filter descriptions and known options. `FFix.Filter`
is usually the best place to look up option names while building a pipeline.

Examples below assume `use FFix` inside your module. If you prefer explicit
names, use calls such as `FFix.command/3`, `FFix.output/2`, and
`FFix.Filter.crop/2`.

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

FFix.to_argv(cmd)
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
  FFix.run!(cmd,
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
    |> drawtext(
      text: "Launch Day",
      x: expr("(w-tw)/2"),
      y: expr("(h-th)/2")
    )
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
  fn src -> src[:video] |> scale(w: 1280, h: -1) end,
  fn video, src -> output("scaled.mp4", video: video, audio: src[:audio]) end,
  global: [y: true]
)
```

```elixir
FFix.to_argv(cmd)
FFix.to_shell_string(cmd)
FFix.run(cmd)
```

`FFix.to_argv/1` is the canonical boundary. `FFix.to_shell_string/1` is for
logs and debugging.

## Requirements

`ffmpeg` must be available when compiling the library. `FFix` generates filter
helpers from local ffmpeg metadata at compile time, so generated functions match
the ffmpeg version in the build environment.

Set `FFMPEG_BIN=/path/to/ffmpeg` if the executable is not named `ffmpeg` or is
not on `PATH`.

## Installation

```elixir
def deps do
  [
    {:ffix, "~> 0.1.0"}
  ]
end
```

## More

Start with the `FFix` module docs for the command model, option placement, graph
return shapes, and output mapping. See `FFix.Graph` for graph construction and
parsing, `FFix.Filter` for generated filter helpers, and `FFix.Runner` for
streaming execution events.

For a runnable walkthrough, see [`livebooks/intro.livemd`](livebooks/intro.livemd).
