# FF

`FF` builds `ffmpeg` filtergraphs and full `ffmpeg` commands as Elixir data.

It is designed for people who want something more structured than hand-built `-filter_complex` and `-map` strings, but still want the generated command to stay explicit and predictable.

The library is built around a simple model:

1. declare command inputs
2. build a graph from streams
3. export named graph outputs
4. map those outputs into one or more files

Most examples below use the macro DSL via `use FF`, but the macro is only authoring sugar. The real model is an explicit `%FF.Graph{}` plus `%FF.Command{}`. That graph model is what makes branching, reusable graph functions, terminals, and predictable rendering work.

## Installation

Add `ff` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ff, "~> 0.1.0"}
  ]
end
```

If you want to execute the generated commands, `ffmpeg` needs to be available on your `PATH`.

## Quick Start

In a module, `use FF` imports:

- the high-level `command(...)` DSL
- generated filter functions like `scale/2`, `fps/2`, `overlay/3`
- `expr/1` for raw ffmpeg expressions when needed

```elixir
defmodule VideoPipeline do
  use FF
end
```

## Step 1: Start Simple

Here is the smallest useful command: take one input and write one output.

```elixir
defmodule VideoPipeline do
  use FF

  def copy do
    command(
      inputs: [
        src: input("input.mp4")
      ],
      outputs: [
        output("out.mp4",
          video: src[:video],
          audio: src[:audio],
          vcodec: :copy,
          acodec: :copy
        )
      ]
    )
  end
end
```

A few things are already happening here:

- `inputs:` declares named command inputs
- `src[:video]` and `src[:audio]` select streams from that input
- `outputs:` describes the output in terms of stream roles like `video:` and `audio:`

That output API is deliberate: most of the time you want to say what each stream *is for*, not manually assemble low-level `-map` entries.

## Step 2: Add a Filter Graph

Now let’s actually transform the video.

```elixir
defmodule VideoPipeline do
  use FF

  def resize do
    command(
      inputs: [
        src: input("input.mp4")
      ],
      graph: [
        main: src[:video] |> scale(w: 1280, h: -1)
      ],
      outputs: [
        output("out.mp4",
          video: :main,
          audio: src[:audio],
          vcodec: :libx264,
          acodec: :aac
        )
      ]
    )
  end
end
```

Here the mental model is:

- `graph:` builds filtered streams
- `main:` gives one of those streams a name
- `output(..., video: :main, ...)` consumes that named graph export

When `graph:` is written as a keyword list, it is just sugar for `FF.graph(outputs: [...])`.

That graph model is the main feature of the library. The macro is there to make authoring nicer, but the valuable part is that you are building a real graph value instead of assembling a fragile `-filter_complex` string.

## Step 3: Reuse Graphs as Ordinary Functions

Graphs do not have to be inline.

This is the preferred way to build reusable pieces: write ordinary Elixir functions that accept streams and return a `%FF.Graph{}`.

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

  def master_and_thumbnails do
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
        output("thumb-%03d.jpg",
          video: :preview,
          f: :image2,
          vsync: 0
        )
      ]
    )
  end
end
```

This example shows a few important ideas:

- one graph can branch into multiple named outputs
- one command can write multiple files
- `graph:` can take a real graph value, not just inline DSL sugar

## Step 4: Build Bigger Filtergraphs

This is where `FF` is most useful: bigger, more branchy filtergraphs that would be annoying to manage as strings.

A graph can:

- branch one input stream into multiple processing paths
- export several named results
- keep internal debug or analysis branches that do not become outputs
- combine streams from different command inputs
- stay reusable as ordinary Elixir code

### Branch and keep a debug branch

```elixir
defmodule VideoPipeline do
  use FF

  def variants_with_debug(video) do
    [master, preview, debug] = split(video, outputs: 3)

    debug_sink =
      debug
      |> fps(fps: 1)
      |> showinfo()
      |> nullsink()

    FF.graph(
      outputs: [
        master: master |> scale(w: 1280, h: -1),
        preview: preview |> fps(fps: 1) |> scale(w: 320, h: -1)
      ],
      terminals: [debug_sink]
    )
  end
end
```

Here, `master` and `preview` are exported, while the `debug` branch stays inside the graph and ends intentionally in `nullsink()`.

### Build a longer graph from several streams

```elixir
defmodule VideoPipeline do
  use FF

  def promo_assets(video, narration, logo) do
    [master, preview] = split(video, outputs: 2)

    FF.graph(
      outputs: [
        master:
          master
          |> trim(duration: 30)
          |> setpts(expr: expr("PTS-STARTPTS"))
          |> scale(w: 1280, h: -1)
          |> overlay(logo, x: expr("W-w-24"), y: 24),
        preview:
          preview
          |> trim(duration: 30)
          |> fps(fps: 1)
          |> scale(w: 320, h: -1),
        audio:
          narration
          |> atrim(duration: 30)
          |> asetpts(expr: expr("PTS-STARTPTS"))
      ]
    )
  end

  def promo_package do
    command(
      inputs: [
        src: input("input.mp4"),
        logo: input("logo.png", loop: 1, framerate: 1),
        narration: input("narration.wav")
      ],
      graph: promo_assets(src[:video], narration[:audio], logo[:video]),
      outputs: [
        output("promo.mp4",
          video: :master,
          audio: :audio,
          vcodec: :libx264,
          acodec: :aac
        ),
        output("promo-thumb-%03d.jpg",
          video: :preview,
          f: :image2,
          vsync: 0
        )
      ]
    )
  end
end
```

This is the core pitch of the library: long, practical filtergraphs can stay as ordinary Elixir values with named exports, instead of becoming one large quoted string.

## Step 5: Use Expressions When Needed

Most options can stay plain Elixir values. For raw ffmpeg expressions, use `expr/1`.

```elixir
defmodule VideoPipeline do
  use FF

  def with_logo do
    command(
      inputs: [
        src: input("input.mp4"),
        logo: input("logo.png", loop: 1, framerate: 1)
      ],
      graph: [
        video:
          src[:video]
          |> overlay(logo[:video], x: expr("W-w-20"), y: 20)
      ],
      outputs: [
        output("out.mp4",
          video: :video,
          audio: src[:audio],
          vcodec: :libx264,
          acodec: :copy
        )
      ]
    )
  end
end
```

The goal is to keep most values normal and only reach for raw ffmpeg syntax at the boundary where it is actually needed.

## Step 6: Output Mapping, from Common to Advanced

For most commands, the high-level role-based API is enough:

```elixir
output("master.mp4",
  video: :master,
  audio: src[:audio],
  vcodec: :libx264,
  acodec: :aac
)
```

Multiple streams of the same kind can be passed as a list:

```elixir
output("with-extra-audio.mkv",
  video: :master,
  audio: [src[audio: 0], src[audio: 1]],
  acodec: :copy
)
```

When exact stream order matters, use `sources:` as the low-level escape hatch:

```elixir
output("archive.mkv",
  sources: [:master, src[audio: 1], src[audio: 0]],
  acodec: :copy
)
```

Use `video:` / `audio:` first. Reach for `sources:` only when you need explicit ordering or unusual mappings.

## Step 7: Turn a Command into `ffmpeg`

`FF` keeps execution based on argv.

```elixir
command = VideoPipeline.master_and_thumbnails()

argv = FF.to_argv(command)
shell = FF.to_shell_string(command)
```

A few rules of thumb:

- `FF.to_argv/1` is the canonical form for execution
- `FF.to_shell_string/1` is for logging and debugging
- `FF.run/1,2` and `FF.run!/1,2` execute commands and return typed results
- `FF.stream/1,2` and `FF.stream!/1,2` expose a lazy event stream when you want pull-based output handling
- `FF.validate!/1` is useful when you want to fail early

For example:

```elixir
command = VideoPipeline.resize()

FF.validate!(command)

{:ok, result} = FF.run(command)

result.exit_status
#=> 0
```

`FF.run!/2` is available when you want a raising variant:

```elixir
result = FF.run!(command, stderr: :collect)

result.stderr
```

When you want to consume output lazily with back-pressure, use `FF.stream/2`:

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

## Step 8: The Plain Runtime API Is Still There

The macro DSL is only surface sugar. Underneath, the runtime API stays explicit.

```elixir
src = FF.Command.input("input.mp4")

graph =
  FF.graph(
    outputs: [
      preview: src[:video] |> FF.Filter.scale(w: 320, h: -1)
    ]
  )

command =
  FF.command(
    inputs: [src],
    graph: graph,
    outputs: [
      FF.Command.output("thumb-%03d.jpg", graph[:preview], f: :image2, vsync: 0)
    ]
  )
```

This is useful when:

- you want to construct commands dynamically
- you do not want macro sugar in a particular part of the codebase
- you want to manipulate `%FF.Command{}` and `%FF.Graph{}` values directly

A couple of small conveniences still help here:

- `graph[:preview]` looks up a named graph export
- `graph[0]` looks up an export by position
- `src[:video]` and `src[audio: 1]` still work on plain `%FF.Command.Input{}` values

## Step 9: Parse and Re-Render Filtergraphs

`FF` can also parse filtergraphs and turn them back into the canonical graph representation.

```elixir
graph = FF.Graph.parse!("[0:v]scale=w=320:h=-1[preview]")

FF.to_filtergraph(graph)
#=> "[0:v]scale=w=320:h=-1[preview];"
```

This is especially useful when you want to:

- inspect a filtergraph as data
- transform one of your own rendered graphs
- round-trip through parse and render without hand-editing strings

Parsing is pragmatic rather than ambitious: the current focus is on reliably handling the filtergraphs `FF` renders itself, plus common ffmpeg syntax around that.

## Summary

`FF` tries to make `ffmpeg` feel like structured Elixir instead of shell-string assembly:

- inputs are named and reusable
- graphs are explicit values
- outputs read in terms of stream roles
- commands serialize back to normal `ffmpeg` argv

Use the macro DSL when you want the nicest authoring experience.
Use the plain runtime API when you want maximum explicitness.
Both lead to the same graph-first command model.
