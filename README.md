# FFix

[![Hex.pm](https://img.shields.io/hexpm/v/ffix.svg)](https://hex.pm/packages/ffix)
[![Documentation](https://img.shields.io/badge/docs-hexdocs.pm-blue.svg)](https://hexdocs.pm/ffix)
[![CI](https://github.com/akash-akya/ffix/actions/workflows/ci.yaml/badge.svg)](https://github.com/akash-akya/ffix/actions/workflows/ci.yaml)
[![License](https://img.shields.io/hexpm/l/ffix.svg)](https://github.com/akash-akya/ffix/blob/master/LICENSE)
[![Elixir](https://img.shields.io/badge/elixir-%7E%3E%201.16-4B275F.svg)](https://elixir-lang.org/)

FFix brings [FFmpeg](https://ffmpeg.org/) to Elixir. Convert recordings, extract
audio, resize videos, or build several renditions from the same source. Choose
streams, codecs, and containers with ordinary Elixir functions, then inspect or
run the resulting command.

Start with a file conversion. Add filters when you need to change the picture
or sound. For larger jobs, compose filtergraphs, reuse pipelines, and write
multiple outputs in one FFmpeg invocation.

## Installation

Add FFix to your dependencies:

```elixir
def deps do
  [{:ffix, "~> 0.1.0"}]
end
```

FFix requires Elixir 1.16 or later. Install [FFmpeg](https://ffmpeg.org/download.html)
and make `ffmpeg` available on your `PATH` to run commands. You can also choose
an executable with `FFMPEG_BIN` or the runner's `ffmpeg:` option.

## Your first conversion

Extract the first audio track from an interview and save it as a WAV file:

```elixir
command =
  FFix.input("interview.mp4")
  |> FFix.audio(0)
  |> FFix.output("interview.wav")
  |> FFix.command()

FFix.run!(command)
```

`0` selects the first audio track. The output filename lets FFmpeg choose the
WAV format and its default audio encoder. Building the command prepares the
instructions; `run!` executes them.

> **Tip:** Call `FFix.to_shell_string(command)` to inspect the FFmpeg command
> before running it. Use `FFix.to_argv(command)` when passing arguments to
> another process library.

## Choose the quality and format

For more control, configure an encoder and a muxer. The encoder compresses the
media; the muxer writes it into a container file.

```elixir
alias FFix.{Encoder, Muxer}

command =
  FFix.input("interview.wav")
  |> FFix.audio(0)
  |> Encoder.aac(b: "128k")
  |> Muxer.mp4("interview.m4a")
  |> FFix.command()

FFix.run!(command)
```

## Next steps

The [FFix guide](https://hexdocs.pm/ffix/FFix.html) builds up from these examples
to stream copy, filtering, and multiple outputs.

- [Encoders](https://hexdocs.pm/ffix/FFix.Encoder.html): codecs, quality, and bitrate.
- [Muxers](https://hexdocs.pm/ffix/FFix.Muxer.html): MP4, Matroska, HLS, and other output formats.
- [Filters](https://hexdocs.pm/ffix/FFix.Filter.html): resize, crop, mix, overlay, and branch streams.
- [Reusable graphs](https://hexdocs.pm/ffix/FFix.Graph.html): parse FFmpeg filtergraphs and bind them to inputs.
- [Execution](https://hexdocs.pm/ffix/FFix.Runner.html): progress, piping, results, and error handling.
- [Discovery](https://hexdocs.pm/ffix/FFix.Discovery.html): inspect the capabilities of your FFmpeg build.

For a runnable walkthrough, see [`livebooks/intro.livemd`](livebooks/intro.livemd).
