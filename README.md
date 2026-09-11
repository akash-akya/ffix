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
      output([cropped, src[:audio]], "square.mp4")
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
      output([scaled], :stdout, f: :image2pipe, vcodec: :png)
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
    output([short, src[:audio]], "short.mp4")
  end
)
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
Values may be scalars or `FFix.expr/1` expressions; use strings for compound syntax
and repeated `:pos` pairs for positional arguments. Escaping happens on serialization.
`Graph.parse!/1` still needs known-filter metadata; text does not retain declared
output media for unknown filters.

Graph values live under `FFix.Graph`: `StreamRef` identifies an input selection or
filter output, `Terminal` ends a branch, and `Expr` holds an expression. The helpers
construct these values for you. Output `Mapping` values remain under `FFix.Command`
and describe how an output uses a reference, including its encoding.

## Run Or Inspect

Command-level options are the final argument:

```elixir
command(
  "input.mp4",
  fn src -> src[:video] |> scale(w: 1280, h: -1) end,
  fn video, src -> output([video, src[:audio]], "scaled.mp4") end,
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

## Codec And Format Shortcuts

Named helpers construct the same command data without manual structs:

```elixir
alias FFix.{Decoder, Demuxer, Encoder, Muxer}

source =
  Demuxer.mov("input.mp4")
  |> Decoder.h264({:video, 0}, threads: 2)

cmd =
  FFix.command(source, fn source ->
    scaled = FFix.Filter.scale(FFix.video(source), w: 1280, h: -2)

    Muxer.mp4(
      [Encoder.libx264(scaled, crf: 18, preset: "slow"), FFix.stream_copy(FFix.audio(source))],
      "main.mp4",
      movflags: [:faststart],
      output_options: [t: 10]
    )
  end)

FFix.to_argv(cmd)
```

This example assumes H.264 video and copy-compatible audio. Usually you can
omit explicit demuxer/decoder selection and pass `"input.mp4"` directly.

`command/2` receives normalized inputs and collects the filter plans attached to
its returned outputs. It neither runs FFmpeg nor inserts implicit splits. Keep
`command/3` for separate graph/output callbacks, or `Command.new/1` and
`FFix.graph/1` for explicit graph settings, terminal sinks, and reusable exports.
The one-callback form accepts `global: [...]` as a third argument.

| Helper | Returns |
| --- | --- |
| `video(input, index \\ 0)`, `audio(input, index \\ 0)` | One input stream reference |
| `Encoder.libx264(stream, options)` | One configured output mapping |
| `stream_copy(stream)` | One packet-copy mapping, not the `copy` video filter |
| `Muxer.mp4(sources, target, options)` | An output declaration |
| `Demuxer.mov(source, options)` | An input declaration |
| `Decoder.h264(input, selector, options)` | An updated input declaration |

Only options are optional in codec and format helpers. Inputs take a source;
outputs take a source or ordered source list before the target. Decoder helpers
require an indexed selector. Generic operations are `Encoder.encode/3`,
`Decoder.decode/4`, `Muxer.mux/4`, and `Demuxer.demux/3`; shortcuts fix only the
codec or format argument.

`use FFix` imports the selectors, `stream_copy`, and command/input/output helpers
alongside the existing filters. Encoder, decoder, and format helpers remain
module-qualified to avoid name collisions.

### Compose Ordinary Functions

```elixir
def web_video(source, options \\ []) do
  Encoder.libx264(source, Keyword.merge([crf: 18, preset: "slow"], options))
end
```

```elixir
FFix.command("input.mp4", fn source ->
  Muxer.matroska(
    [
      FFix.stream_copy(FFix.audio(source)),
      web_video(FFix.video(source)),
      web_video(FFix.video(source), crf: 28)
    ],
    "qualities.mkv"
  )
end)
```

The audio becomes output stream 0, and the two independent video encodes become
streams 1 and 2. Encoder options receive those indexes automatically. Indexes
restart for each output. Reusing a mapping does not share encoded packets.

Use `video/1`, `audio/1`, or explicit indexed access for configured mappings.
Broad selectors such as `source[:audio]` can select several streams and retain
that meaning. If an output contains configured encoding, all its mappings must
select individual streams. Actual filtered outputs cannot use stream copy and
must be mapped exactly once; use `split` or `asplit` for multiple consumers.

Configure inputs before passing them into a command, for example
`Decoder.aac(input, {:audio, 0}, threads: 2)`. Updating an input preserves its
identity, but does not mutate an input already held by an existing command.
Independent decoding of the same track requires separate input declarations.

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
For `"h264"`, FFmpeg selects the encoder; implementation-specific options depend
on that choice. `Encoder.libx264/2` fixes the implementation and adds recorded
option validation.

`raw:` bypasses metadata checks, not structural safety checks. Duplicated options,
pre-scoped component keys, and conflicting raw codec/format selections are
rejected. Use `output_options:` for raw output CLI controls on muxer shortcuts,
and `input_options:` for raw input controls on demuxer shortcuts. Those options
are not muxer/demuxer AVOptions.

The generic `input(source, options)` and `output(sources, target, options)` support
automatic format selection and raw CLI options; options default to `[]`. They
also accept independent configurations via `demuxer:`/`decoders:` and `muxer:`
respectively. The four configuration modules
provide `new/2` constructors for this lower layer; `name: nil` leaves selection
to FFmpeg. Outputs store ordered `Mapping` values in `mappings`, not `sources`;
existing source-taking output helpers wrap bare references automatically.

### Named Streams In Option Callbacks

Give output mappings names when another option needs to refer to them. Option
callbacks receive a plain map of their **final output positions**, so reordering
mappings does not leave stale indexes inside strings:

```elixir
FFix.command("input.mp4", fn source ->
  [high, low] = FFix.Filter.split(FFix.video(source), outputs: 2)

  video_720 =
    high
    |> FFix.Filter.scale(w: -2, h: 720)
    |> Encoder.libx264(b: "800k", maxrate: "800k", bufsize: "1600k")

  video_360 =
    low
    |> FFix.Filter.scale(w: -2, h: 360)
    |> Encoder.libx264(b: "400k", maxrate: "400k", bufsize: "800k", g: 12)

  audio_track = Encoder.aac(FFix.audio(source), b: "64k")

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
end)
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

An output using callbacks must select one known audio/video stream per mapping,
including unnamed ones. Broad/raw selectors and unknown filter output media are
rejected rather than guessed; use `FFix.shape/2` for dynamic filter shapes when
needed. This does not probe media files. Input and global options do not receive
output-stream callbacks.

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

Set `FFMPEG_BIN=/path/to/ffmpeg` for execution/discovery when the executable is
not on `PATH`, or pass `--ffmpeg /path/to/ffmpeg` to the refresh task.

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
