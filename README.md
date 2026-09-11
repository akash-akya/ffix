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

`FFix.Filter` exposes ordinary functions from recorded FFmpeg metadata, including
the complete 551-filter catalog of the FFmpeg 7.1.5 baseline:
`scale/2`, `crop/2`, `overlay/3`, `drawtext/2`, `fps/2`, and so on.

The generated docs include filter descriptions and known options. `FFix.Filter`
is usually the best place to look up option names while building a pipeline.

Examples use qualified calls and aliases:

```elixir
alias FFix.{Decoder, Demuxer, Encoder, Filter, Graph, Muxer}
```

Declare inputs, select streams, apply filters, and declare outputs. Then pass
those outputs to `FFix.command/2`; it collects their input dependencies.

## Crop A Video

```elixir
source = FFix.input("input.mp4")
cropped = source |> FFix.video() |> Filter.crop(w: 720, h: 720)
output = FFix.output([cropped, FFix.audio(source)], "square.mp4")
cmd = FFix.command(output)

FFix.to_argv(cmd)
```

## Pipe An Image

```elixir
image = FFix.input(:stdin, f: :image2pipe)
scaled = image |> FFix.video() |> Filter.scale(w: 640, h: -1)
output = FFix.output(scaled, :stdout, f: :image2pipe, vcodec: :png)
cmd = FFix.command(output)

result =
  FFix.run!(cmd,
    stdin: File.stream!("input.png", [], 2048),
    stdout: :collect
  )

File.write!("small.png", result.stdout)
```

## Vertical Short

```elixir
source = FFix.input("input.mp4")

short =
  source
  |> FFix.video()
  |> Filter.scale(w: 1080, h: 1920, force_original_aspect_ratio: :increase)
  |> Filter.crop(w: 1080, h: 1920)
  |> Filter.fps(fps: 30)
  |> Filter.drawtext(text: "Launch Day", x: "(w-tw)/2", y: "(h-th)/2")

output = FFix.output([short, FFix.audio(source)], "short.mp4")
FFix.command(output)
```

## Generic Filters

Named filter helpers validate options and infer output shapes from metadata.
For names or options outside that metadata, use an explicit generic operation:

```elixir
video |> FFix.Filter.filter("vendor_filter", [:video], strength: 0.5)
FFix.filter([background, foreground], "overlay", [:video], x: 10, y: 20)

[high, low] =
  FFix.Filter.filter(video, "split", [:video, :video], outputs: 2)
```

The arguments are inputs, name, output media, then optional filter options.
Generic calls never consult metadata, even for known names. Output media declares
pad count and order; it does not emit FFmpeg options or infer their defaults.
Use `[]` inputs for source filters and `[]` output media for sinks. One output
returns a reference, multiple outputs return a list, and sinks return a terminal.
Use plain strings for expressions and compound syntax, and repeated `:pos` pairs
for positional arguments. Escaping happens at the serialization boundary.
Named helpers raise when their output shape cannot be resolved; use the generic
filter with explicit ordered media in that case. For example,
`Filter.ebur128(audio, video: true)` returns `[video, audio]`, while
`Filter.ebur128(audio, video: false)` returns one audio reference.
`Graph.parse!/1` still needs known-filter metadata; text does not retain declared
output media for unknown filters.

Graph values live under `FFix.Graph`: `StreamRef` identifies an input selection or
filter output, and `Terminal` ends a branch. The helpers construct these values
for you. Output `Mapping` values remain under `FFix.Command` and describe how an
output uses a reference, including its encoding.

## Run Or Inspect

Command-level options are the final argument:

```elixir
source = FFix.input("input.mp4")
video = source |> FFix.video() |> Filter.scale(w: 1280, h: -1)
output = FFix.output([video, FFix.audio(source)], "scaled.mp4")
cmd = FFix.command(output, global: [y: :flag])
```

```elixir
FFix.to_argv(cmd)
FFix.to_shell_string(cmd)
FFix.run(cmd)
```

`FFix.to_argv/1` is the canonical boundary. `FFix.to_shell_string/1` is for
logs and debugging. Raw CLI switches use `:flag`; `true` and `false` emit `1` and `0`,
not valueless switches. Filter and component booleans keep their usual meaning.

`FFix.run/2` returns `{:ok, result}` or `{:error, error}` for operational failures;
`FFix.run!/2` raises `FFix.Runner.Error` for those failures. Application callback
exceptions propagate unchanged. `FFix.stream/2` is lazy: each enumeration starts
a fresh execution. Live events are separate from bounded retained diagnostics;
collecting all events yourself can still use unbounded memory.

## Codec And Format Shortcuts

Named helpers construct the same command data without manual structs:

```elixir
alias FFix.{Decoder, Demuxer, Encoder, Muxer}

source =
  Demuxer.mov("input.mp4")
  |> Decoder.h264({:video, 0}, threads: 2)

scaled = Filter.scale(FFix.video(source), w: 1280, h: -2)

output =
  Muxer.mp4(
    [Encoder.libx264(scaled, crf: 18, preset: "slow"), FFix.stream_copy(FFix.audio(source))],
    "main.mp4",
    movflags: [:faststart],
    output_options: [t: 10]
  )

cmd = FFix.command(output)

FFix.to_argv(cmd)
```

This example assumes H.264 video and copy-compatible audio. Usually you can
omit explicit demuxer/decoder selection and use `FFix.input("input.mp4")`.

`FFix.command(output_or_outputs, options \\ [])` collects filter plans and infers
inputs by declaration identity, not filename. It neither runs FFmpeg nor inserts
implicit splits. Its options are `global:`, an explicit ordered `inputs:` list,
`terminals:` for sink branches, and `settings:` for graph settings. Use `inputs:`
when positional graph references, metadata-only inputs, or a required input
order make inference unsuitable.

| Helper | Returns |
| --- | --- |
| `FFix.video(input, index \\ 0)`, `FFix.audio(input, index \\ 0)`, `FFix.subtitle(input, index \\ 0)` | One input stream reference |
| `Encoder.libx264(stream, options)` | One configured output mapping |
| `FFix.stream_copy(stream)` | One packet-copy mapping, not the `copy` video filter |
| `Muxer.mp4(sources, target, options)` | An output declaration |
| `Demuxer.mov(source, options)` | An input declaration |
| `Decoder.h264(input, selector, options)` | An updated input declaration |

Only options are optional in codec and format helpers. Inputs take a source;
outputs take a source or ordered source list before the target. Decoder helpers
require an indexed selector. Generic operations are `Encoder.encode/3`,
`Decoder.decode/4`, `Muxer.mux/4`, and `Demuxer.demux/3`; shortcuts fix only the
codec or format argument.

Keep component and filter calls qualified with aliases to avoid name collisions.

### Compose Ordinary Functions

```elixir
def web_video(source, options \\ []) do
  Encoder.libx264(source, Keyword.merge([crf: 18, preset: "slow"], options))
end
```

```elixir
source = FFix.input("input.mp4")

output =
  Muxer.matroska(
    [
      FFix.stream_copy(FFix.audio(source)),
      web_video(FFix.video(source)),
      web_video(FFix.video(source), crf: 28)
    ],
    "qualities.mkv"
  )

FFix.command(output)
```

The audio becomes output stream 0, and the two independent video encodes become
streams 1 and 2. Encoder options receive those indexes automatically. Indexes
restart for each output. Reusing a mapping does not share encoded packets.

Use `FFix.video/2`, `FFix.audio/2`, or `FFix.subtitle/2` for indexed selections
(default index 0). `FFix.select/2` accepts `:all`, `{media, :all}`, `{media, index}`,
`{:index, n}`, and `{:raw, "s?"}`. Media can be `:video`, `:audio`, `:subtitle`,
`:data`, or `:attachment`. Broad selectors such as
`FFix.select(source, {:audio, :all})` can select several streams and retain
that meaning. If an output contains configured encoding, all its mappings must
select individual streams. Actual filtered outputs cannot use stream copy and
must be mapped exactly once; use `split` or `asplit` for multiple consumers.

Configure inputs and decoders before selecting streams, for example
`Decoder.aac(input, {:audio, 0}, threads: 2)`. Selections capture immutable input
snapshots. Updating an input preserves its identity but cannot update existing
selections; combining conflicting snapshots raises. Independent decoder or seek
configurations for the same file require separate input declarations. Within one
input, use either absolute `{:index, n}` or media-relative `{media, n}` decoder
selectors, not both: their targets can overlap without media probing.

### Reuse Graph Data

```elixir
port = Graph.input(:picture, :video)
template = FFix.graph(outputs: [preview: Filter.scale(port, w: 320, h: -2)])
source = FFix.input("input.mp4")
instance = Graph.bind(template, picture: FFix.video(source))
flipped = Filter.hflip(instance[:preview])
output = FFix.output(flipped, "preview.mp4")
FFix.command(output)
```

Each binding gives the template's filters fresh identities. Graph Access is
read-only and returns filterable `StreamRef` values; the internal `graph.exports`
field contains canonical handles for low-level use. Parsed graphs can bind input
declarations too: `Graph.bind(Graph.parse!("[0:v]hflip[preview]"), %{0 => source})`.

An instance retains every node, output pad, terminal branch, and setting, even
when you select only one export. Consume all produced outputs or connect unused
ones to explicit sinks; final serialization rejects unused pads. No split is
inserted automatically. Direct input selections can be reused, but sharing a
filtered pad still requires `Filter.split/2` or `Filter.asplit/2`. For sink-only
instances, pass `terminals: Graph.terminals(instance)` to `FFix.command/2`.

### Options And Escape Hatches

Named helpers include documentation, option typespecs, and basic validation from
a recorded FFmpeg 7.1.5 baseline. They cover a selected set of common codecs and
formats, not every registration. They do not query the installed build, emit
reported defaults, or guarantee codec/container compatibility or hardware
availability. Applicable shared options supplement private help; metadata owners
remain distinct when names overlap.

Component options have no leading dash or stream specifier. Booleans are explicit
values, and flag lists become FFmpeg strings. Other compound values use strings;
array delimiters are not guessed. Strings remain open values, so validation does
not pretend FFmpeg's reported constants and ranges are exhaustive.

```elixir
Encoder.libx264(video, crf: 18, raw: [{"new_option", "value"}])
Encoder.encode(video, "h264", crf: 23, preset: "slow")
Encoder.encode(video, "vendor_encoder", [{"vendor_option", "value"}])
Muxer.mux([mapped_video], "vendor_muxer", "out.file")
Demuxer.demux("in.file", "vendor_demuxer", [{"vendor_option", "value"}])
Decoder.decode(input, "vendor_decoder", {:video, 0}, [{"vendor_option", "value"}])
```

`Encoder.encode/3` forwards the supplied name without choosing an implementation.
`"h264"` is a literal FFmpeg codec request, not an FFix alias for `"libx264"`;
implementation-specific options depend on FFmpeg's selection. `Encoder.libx264/2`
fixes the implementation and adds recorded option validation.

`raw:` bypasses metadata checks, not structural safety checks. Duplicated options,
pre-scoped component keys, and conflicting raw codec/format selections are
rejected. Use `output_options:` for raw output CLI controls on muxer shortcuts,
and `input_options:` for raw input controls on demuxer shortcuts. Those options
are not muxer/demuxer AVOptions.

The generic `FFix.input(source, options)` and
`FFix.output(sources, target, options)` support automatic format selection and raw
CLI options; options default to `[]`. They
also accept independent configurations via `demuxer:`/`decoders:` and `muxer:`
respectively. The four configuration modules
provide `new/2` constructors for this lower layer; `name: nil` leaves selection
to FFmpeg. Outputs store ordered `Mapping` values in `mappings`, not `sources`;
existing source-taking output helpers wrap bare references automatically.
`FFix.Command.Input.new/2` and `FFix.Command.Output.new/3` also construct these
declarations. Low-level `Command.add_input/2` and `Command.add_output/2` append
existing structs; they do not construct declarations. `Command.new/1` requires
explicit inputs and a graph with canonical `graph.exports` handles, or direct
input selections. It does not infer dependencies or collect graph reference
contexts, and it still checks captured input snapshots.

### Named Streams In Option Callbacks

Give output mappings names when another option needs to refer to them. Option
callbacks receive a plain map of their **final output positions**, so reordering
mappings does not leave stale indexes inside strings:

```elixir
source = FFix.input("input.mp4")
[high, low] = Filter.split(FFix.video(source), outputs: 2)

video_720 =
  high
  |> Filter.scale(w: -2, h: 720)
  |> Encoder.libx264(b: "800k", maxrate: "800k", bufsize: "1600k")

video_360 =
  low
  |> Filter.scale(w: -2, h: 360)
  |> Encoder.libx264(b: "400k", maxrate: "400k", bufsize: "800k", g: 12)

audio_track = Encoder.aac(FFix.audio(source), b: "64k")

output =
  Muxer.hls(
    [v720: video_720, v360: video_360, aud: audio_track],
    "out/%v.m3u8",
    hls_time: 2,
    var_stream_map: fn streams ->
      "#{streams.v720.specifier},agroup:a,name:720p " <>
        "#{streams.v360.specifier},agroup:a,name:360p " <>
        "#{streams.aud.specifier},agroup:a,name:audio,default:yes"
    end
  )

cmd = FFix.command(output)
```

Create the output directory before executing this command. The example preserves
one shared audio rendition rather than encoding the same audio for each video.

The callback receives:

```elixir
%{
  v720: %{index: 0, specifier: "v:0"},
  v360: %{index: 1, specifier: "v:1"},
  aud: %{index: 2, specifier: "a:0"}
}
```

`index` is absolute within the output. `specifier` counts within video or audio.
With `[aud: audio_track, v360: video_360, v720: video_720]` as the sources, `v720`
becomes `%{index: 2, specifier: "v:1"}` and its encoding settings follow it too.
Indexes restart for each output. Names are explicit atoms, unique within that
output; they are not inferred from variable names or graph export labels.

This is generic: encoder options, muxer options, and raw output CLI options can
all accept callbacks. There is no special parser for `var_stream_map`. Callbacks
return ordinary option values, including flag lists on named helpers. Unknown
option names are checked immediately; metadata value checks run on the returned
value during serialization. Raw strings and unnamed mappings remain supported.
Unnamed mappings count toward indexes but do not appear in the callback map.

Callbacks run once per supplied option **per serialization**, not when building
or structurally validating a command. Keep them pure: printing and executing a
command can each call them. A missing name raises `KeyError`; callback exceptions
are not hidden. A callback cannot return another callback or change mappings.

An output using callbacks must select one stream with known media per mapping,
including unnamed ones. Broad/raw selectors and unknown filter output media are
rejected rather than guessed; use `Filter.filter/4` with explicit ordered media
when a named filter's shape cannot be resolved. This does not probe media files.
Input and global options do not receive output-stream callbacks.

### Refresh Helper Metadata

An internal macro defines the named functions, docs, and typespecs from
`priv/ffmpeg/metadata.exs` during compilation, without querying FFmpeg.
Refresh the recorded metadata explicitly:

```sh
mix ffix.refresh.metadata --ffmpeg /usr/bin/ffmpeg
```

The snapshot contains selected codecs/formats and every filter in the captured
build. Filter catalog signatures and parsed help remain separate, preserving
private, child, and framesync option sections. Helpers expose the primary and
framesync options; recording child sections does not silently enable new options.

Refresh captures everything before atomically replacing the snapshot. It rejects
missing previously recorded filters; intentional removals require editing the
baseline first. Reproducing a capture requires the same FFmpeg build. Metadata
changes rebuild the helpers on the next compilation. Generic operations remain
available for names or options outside the baseline.

## Discover FFmpeg Capabilities

`FFix.Discovery` inspects the installed build without adding a command DSL:

```elixir
{:ok, encoders} = FFix.Discovery.list(:encoder)
{:ok, details} = FFix.Discovery.help(:encoder, "libx264")
{:ok, pixels} = FFix.Discovery.list(:pixel_format)
{:ok, shared} = FFix.Discovery.shared()
{:ok, build} = FFix.Discovery.version()
```

It also covers decoders, muxers, demuxers, devices, filters, protocols,
bitstream filters, sample formats, channels/layouts, hardware acceleration,
dispositions, and colors. Availability depends on the FFmpeg build.

Discovery is explicit and bounded; detailed help is fetched on demand. Pass
`ffmpeg: "/path/to/ffmpeg"` to select a build. `FFix.Discovery.Parser` parses
recorded output without subprocesses. Names, aliases, and option sections stay
separate; reported defaults and ranges are metadata, not a complete validator.

## Requirements

FFmpeg is required for execution, discovery, and explicit metadata refresh—not
for compiling the library or constructing graphs and commands. The recorded
baseline fixes the helper API independently of the installed executable;
registration in it does not guarantee local availability or hardware usability.

For Command execution, pass `ffmpeg: "/path/to/ffmpeg"`; otherwise the runner
uses `FFMPEG_BIN`, then `ffmpeg` on `PATH`. Raw argv executes literally, without
executable substitution or added flags. Discovery also accepts `ffmpeg:` and
`FFMPEG_BIN`; the refresh task accepts `--ffmpeg /path/to/ffmpeg`.

## Download FFmpeg For Development

Static builds come from [BtbN](https://github.com/BtbN/FFmpeg-Builds/releases).
Explicitly record a dated build, then download either variant:

```sh
mix ffix.ffmpeg.checksum --release autobuild-2026-09-07-15-39
mix ffix.ffmpeg.fetch --variant gpl
mix ffix.ffmpeg.fetch --variant lgpl
```

Both tasks default to branch `9.0`; use `--branch` to select another branch.
GPL includes libx264/libx265; LGPL excludes them. Downloads are verified against
`priv/ffmpeg/checksums.exs` and extracted under `.ffmpeg/<archive-name>/`.
No environment or helper metadata is changed. BtbN builds track release branches,
not necessarily exact point releases, and older downloads may expire.
Linux builds require glibc 2.28+ and tar/xz; macOS is not supported by BtbN.

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
