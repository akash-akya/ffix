# FF

`FF` builds ffmpeg filtergraphs and full ffmpeg commands as Elixir data.

The goal is to avoid hand-built `-filter_complex` and `-map` strings while
keeping the final command explicit. You build inputs, streams, graphs, and
outputs, then serialize the command directly to argv.

## Installation

Add `ff` to your dependencies:

```elixir
def deps do
  [
    {:ff, "~> 0.1.0"}
  ]
end
```

`ffmpeg` must be available on `PATH` when compiling the library because filter
helpers are generated from local ffmpeg filter metadata. It is also needed when
running commands.

## Quick Start

```elixir
defmodule VideoPipeline do
  use FF

  def resize do
    command(
      inputs: [
        src: input("input.mp4")
      ],
      graph: fn inputs ->
        [
          main: inputs.src[:video] |> scale(w: 1280, h: -1)
        ]
      end,
      outputs: fn graph, %{inputs: inputs} ->
        output("out.mp4",
          video: graph.main,
          audio: inputs.src[:audio],
          vcodec: :libx264,
          acodec: :aac
        )
      end
    )
  end
end
```

```elixir
command = VideoPipeline.resize()

FF.to_argv(command)
FF.to_shell_string(command)
FF.run(command)
```

`FF.to_argv/1` is the canonical boundary. `FF.to_shell_string/1` is for logs and
debugging.

## Command Shape

`FF.command/1` accepts four top-level keys:

```elixir
command(
  global: [y: true],
  inputs: [
    src: input("input.mp4", ss: "00:00:03"),
    music: input("music.mp3")
  ],
  graph: fn inputs ->
    [
      preview: inputs.src[:video] |> scale(w: 320, h: -1)
    ]
  end,
  outputs: fn graph, %{inputs: inputs} ->
    [
      output("preview.mp4",
        video: graph.preview,
        audio: inputs.src[:audio],
        vcodec: :libx264,
        acodec: :aac
      ),
      output("audio.mka",
        audio: [inputs.src[:audio], inputs.music[:audio]],
        acodec: :copy
      )
    ]
  end
)
```

`global:` is a flat list of ffmpeg global options.

`inputs:` is a keyword list of named inputs. Each value must be built with
`input/1` or `input/2`. Named inputs are passed to graph and output callbacks
exactly as a map.

`graph:` is optional. It can be a one-argument function or a `%FF.Graph{}`.

`outputs:` can be a single output, a list of outputs, or a callback.

## Inputs

Declare command inputs with `input/1` or `input/2`.

```elixir
inputs: [
  src: input("input.mp4"),
  logo: input("logo.png", loop: 1, framerate: 1),
  mic: input(:stdin, f: :wav)
]
```

For inputs without options, a string source shortcut is also accepted:

```elixir
inputs: [
  src: "input.mp4"
]
```

Use `input/2` when the input needs options.

Select streams from an input with access syntax:

```elixir
inputs.src[:input]       # whole input, rendered like -map 0
inputs.src[:video]       # rendered like 0:v
inputs.src[:audio]       # rendered like 0:a
inputs.src[audio: 1]     # rendered like 0:a:1
inputs.src[raw: "s?"]    # raw ffmpeg stream selector escape hatch
```

Outside a command callback, build graph input streams explicitly:

```elixir
video = FF.Graph.input(0, :video)
audio = FF.Graph.input(0, :audio)
```

## Graph Callbacks

A graph callback receives the input map directly:

```elixir
graph: fn inputs ->
  [
    main: inputs.src[:video] |> scale(w: 1280, h: -1),
    thumb: inputs.src[:video] |> fps(fps: 1) |> scale(w: 320, h: -1)
  ]
end
```

The callback may return one of these shapes:

```elixir
# A keyword list of exported streams.
[
  main: stream,
  preview: stream
]

# A complete graph value.
FF.graph(
  outputs: [main: stream],
  terminals: [debug_sink]
)

# No filtergraph.
nil
```

Keyword returns are always treated as graph exports. If you need terminals,
settings, or other graph options, return an explicit `%FF.Graph{}` from
`FF.graph/1`.

## Output Callbacks

An output callback may accept one or two arguments.

A one-argument callback receives graph exports directly:

```elixir
outputs: fn graph ->
  output("thumb-%03d.jpg",
    video: graph.preview,
    f: :image2,
    vsync: 0
  )
end
```

A two-argument callback receives graph exports and a context map. The context is
currently `%{inputs: inputs}`:

```elixir
outputs: fn graph, %{inputs: inputs} ->
  output("master.mp4",
    video: graph.main,
    audio: inputs.src[:audio],
    vcodec: :libx264,
    acodec: :aac
  )
end
```

The callback may return a single output or a list of outputs.

When there is no graph, the first argument is an empty map:

```elixir
command(
  inputs: [src: input("input.mp4")],
  outputs: fn _graph, %{inputs: inputs} ->
    output("copy.mp4",
      video: inputs.src[:video],
      audio: inputs.src[:audio],
      vcodec: :copy,
      acodec: :copy
    )
  end
)
```

## Outputs

Use `video:` and `audio:` for common output mappings:

```elixir
output("master.mp4",
  video: graph.main,
  audio: inputs.src[:audio],
  vcodec: :libx264,
  acodec: :aac
)
```

Multiple streams for the same role can be passed as a list:

```elixir
output("with-extra-audio.mkv",
  video: graph.main,
  audio: [inputs.src[audio: 0], inputs.src[audio: 1]],
  acodec: :copy
)
```

Use `sources:` when exact `-map` ordering matters:

```elixir
output("archive.mkv",
  sources: [graph.main, inputs.src[audio: 1], inputs.src[audio: 0]],
  acodec: :copy
)
```

Output options are intentionally flat and ffmpeg-shaped. Keys are rendered as
CLI option names:

```elixir
output("out.mp4",
  video: graph.main,
  "c:v": :libx264,
  "c:a": :aac,
  crf: 23,
  preset: :slow,
  movflags: [:faststart]
)
```

String keys or quoted atom keys are useful for stream-specific options such as
`"c:v"` or `"metadata:s:a:0"`.

## Reusable Graph Functions

Graphs are ordinary Elixir values, so reusable graph pieces can just be
functions that accept and return streams or graphs.

```elixir
defmodule VideoPipeline do
  use FF

  def variants(video) do
    [master, preview] = split(video, outputs: 2)

    FF.graph(
      outputs: [
        master: master |> scale(w: 1280, h: -1),
        preview: preview |> fps(fps: 1) |> scale(w: 320, h: -1)
      ]
    )
  end

  def package do
    command(
      inputs: [src: input("input.mp4")],
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
          output("thumb-%03d.jpg",
            video: graph.preview,
            f: :image2,
            vsync: 0
          )
        ]
      end
    )
  end
end
```

For filters whose output shape depends on options, use `FF.shape/2`:

```elixir
[metered_audio, meter_video] =
  input_audio
  |> ebur128(video: true)
  |> FF.shape([:audio, :video])
```

## Low-Level API

The same model is available without `use FF`.

```elixir
src = FF.input("input.mp4")

preview =
  src[:video]
  |> FF.Filter.scale(w: 320, h: -1)

graph = FF.graph(outputs: [preview: preview])

command =
  FF.command(
    inputs: [src: src],
    graph: graph,
    outputs: [
      FF.output("thumb-%03d.jpg", graph[:preview], f: :image2, vsync: 0)
    ]
  )
```

`%FF.Command{}` and `%FF.Graph{}` are regular structs, and the lower-level
`FF.Command` functions can be used when step-by-step construction is clearer.

## Validation and Execution

`FF.validate!/1` performs structural checks without probing media files or
running ffmpeg. Validation is best-effort and focuses on the command/graph model:

- command outputs must have sources
- graph input refs must point at declared command inputs
- filtered graph exports must be mapped exactly once
- graph nodes and refs must be structurally valid

Execution stays at the edge:

```elixir
argv = FF.to_argv(command)
shell = FF.to_shell_string(command)

{:ok, result} = FF.run(command)
result = FF.run!(command, stderr: :collect)
```

For pull-based execution events:

```elixir
FF.stream(command, progress: true)
|> Enum.each(fn
  {:stdout, chunk} -> IO.binwrite(chunk)
  {:log, log} -> IO.puts(log.message)
  {:progress, progress} -> IO.inspect(progress.status)
  {:exit, result} -> IO.inspect(result.exit_status)
  _event -> :ok
end)
```

## Parsing Filtergraphs

`FF.Graph.parse!/1` can parse common filtergraph syntax into the same graph
model used by the builder.

```elixir
graph = FF.Graph.parse!("[0:v]scale=w=320:h=-1[preview]")

FF.to_filtergraph(graph)
#=> "[0:v]scale=w=320:h=-1[preview];"
```

The parser is pragmatic. It is meant to round-trip graphs produced by `FF` and
common ffmpeg graph syntax, not to model every possible hand-written graph.

## Current Scope

`FF` currently focuses on:

- explicit graph and command data
- predictable argv serialization
- generated filter helpers from local ffmpeg metadata
- thin execution helpers around argv

It does not currently probe media files, run ffmpeg for validation, or maintain
a separate compile stage. Build a command, inspect or validate it if needed, and
pass it directly to `FF.to_argv/1` or `FF.run/1`.
