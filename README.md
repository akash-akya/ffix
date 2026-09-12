# FFix

[![Hex.pm](https://img.shields.io/hexpm/v/ffix.svg)](https://hex.pm/packages/ffix)
[![Documentation](https://img.shields.io/badge/docs-hexdocs.pm-blue.svg)](https://hexdocs.pm/ffix)
[![CI](https://github.com/akash-akya/ffix/actions/workflows/ci.yaml/badge.svg)](https://github.com/akash-akya/ffix/actions/workflows/ci.yaml)
[![License](https://img.shields.io/hexpm/l/ffix.svg)](https://github.com/akash-akya/ffix/blob/master/LICENSE)
[![Elixir](https://img.shields.io/badge/elixir-%7E%3E%201.16-4B275F.svg)](https://elixir-lang.org/)

FFix is an Elixir library for building, inspecting, and running
[FFmpeg](https://ffmpeg.org/) commands by composing ordinary Elixir functions.
Extract an audio track with a short pipeline, or combine inputs, reuse
filtergraphs, and produce several outputs in one run. The same building blocks
support both simple conversions and complex media processing.

## A simple conversion

Extract the first audio track from an interview and save it as a WAV file:

```elixir
command =
  FFix.input("interview.mp4")
  |> FFix.audio(0)
  |> FFix.output("interview.wav")
  |> FFix.command()

FFix.run!(command)
```

`audio(0)` selects the first audio track. The filename lets FFmpeg choose the
WAV format and its default encoder; no filter is needed. An output describes
what to write and where. A command assembles the inputs and outputs;
`run!` starts FFmpeg.

## Multiple outputs from one graph

Create a main video and a two-second preview, both with audio, plus a contact
sheet. Split the video, process each branch, then declare the outputs:

```elixir
alias FFix.{Encoder, Filter, Muxer}

input = FFix.input("interview.mp4")

[main, preview, sheet] =
  input
  |> FFix.video(0)
  |> Filter.split(outputs: 3)

# -2 preserves the aspect ratio with an even height.
main_video =
  main
  |> Filter.scale(w: 640, h: -2)
  |> Encoder.libx264()

preview_video =
  preview
  |> Filter.scale(w: 320, h: -2)
  |> Encoder.libx264()

# Sample once per second and arrange the first four frames into one image.
contact_sheet =
  sheet
  |> Filter.fps(fps: 1)
  |> Filter.scale(w: 160, h: -2)
  |> Filter.tile(layout: "2x2")
  |> Encoder.png()

# Unfiltered input audio can be reused; each MP4 gets its own AAC encode.
audio =
  input
  |> FFix.audio(0)
  |> Encoder.aac()

main_output =
  [main_video, audio]
  |> Muxer.mp4("main.mp4")

preview_output =
  [preview_video, audio]
  |> Muxer.mp4("preview.mp4", output_options: [t: 2])

# Write one PNG file rather than a numbered image sequence.
sheet_output =
  contact_sheet
  |> Muxer.image2("contact-sheet.png", update: true, output_options: ["frames:v": 1])

command = FFix.command([main_output, preview_output, sheet_output])
FFix.run!(command)
```

Encoders control compression; muxers package the tracks. The preview's `t: 2`
limits both video and audio without shortening the main output. Each filtered
branch is mapped once; use `split` whenever it needs multiple consumers.

You can also inspect either command without running it:

```elixir
FFix.to_shell_string(command)
FFix.to_argv(command)
```

Use the argument list with your own process runner if you prefer.

## Beyond the examples

Generated helpers cover hundreds of filters and selected codecs and formats.
Generic functions accept literal FFmpeg names when you need to go beyond them.

- [Streams and formats](https://hexdocs.pm/ffix/FFix.html): select tracks, copy
  without re-encoding, and configure decoders, encoders, demuxers, and muxers.
- [Audio, video, and images](https://hexdocs.pm/ffix/FFix.Filter.html): resize,
  crop, overlay, blend, mix, fade, generate media, and create visualizations.
- [Reusable graphs](https://hexdocs.pm/ffix/FFix.Graph.html): compose pipelines
  with functions, parse existing filtergraphs, and bind them to new inputs.
- [Multiple deliveries](https://hexdocs.pm/ffix/FFix.Command.Output.html): share
  processing between outputs or package adaptive HLS renditions with shared audio.
- [Execution](https://hexdocs.pm/ffix/FFix.Runner.html): work with files, URLs,
  and pipes; stream progress and diagnostics, and handle structured errors.
- [Discovery](https://hexdocs.pm/ffix/FFix.Discovery.html): query the codecs,
  formats, filters, and options available in your FFmpeg build.

## Installation

Add FFix to your dependencies:

```elixir
def deps do
  [{:ffix, "~> 0.1.0"}]
end
```

FFix requires Elixir 1.16 or later. To run commands, install
[FFmpeg](https://ffmpeg.org/download.html) and make `ffmpeg` available on your
`PATH`. You can also choose an executable with `FFMPEG_BIN` or the runner's
`ffmpeg:` option. The multi-output example uses `libx264`, `aac`, and `png`.

## Explore further

- [FFix guide](https://hexdocs.pm/ffix/FFix.html): API concepts, stream selection,
  configuration, and more involved compositions.
- [Interactive Livebook](livebooks/intro.livemd): runnable examples with audio,
  images, sliders, GIFs, video previews, and HLS. Uses your local FFix checkout.
