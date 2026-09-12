defmodule FFix.Filter do
  @moduledoc """
  Transform pictures and sound with FFmpeg filters.

  Filter functions take selected streams followed by options. Chain them with
  Elixir's pipe operator, then choose an encoder and output.

  ## Resize and adjust frame rate

      alias FFix.{Encoder, Filter, Muxer}

      output =
        FFix.input("interview.mp4")
        |> FFix.video(0)
        |> Filter.scale(w: 1280, h: -2)
        |> Filter.fps(fps: 30)
        |> Encoder.libx264(crf: 23)
        |> Muxer.mp4("interview-small.mp4")

      FFix.command(output)

  This selects video only. Add an audio selection to the output when you want
  to retain sound, as shown in the `FFix` guide.

  ## Combine streams

  Filters with a fixed number of inputs take separate arguments. For example,
  `overlay/3` places one video over another:

      source = FFix.input("interview.mp4")
      logo = FFix.input("logo.png")
      picture = Filter.overlay(FFix.video(source, 0), FFix.video(logo, 0), x: 20, y: 20)

  Filters accepting a variable number of streams take a list. This mixes two
  audio recordings, stopping when the shorter one ends:

      voice = FFix.input("voice.wav") |> FFix.audio(0)
      music = FFix.input("music.wav") |> FFix.audio(0)
      mixed = Filter.amix([voice, music], inputs: 2, duration: :shortest)

  ## Branch a stream

  Use `split/2` for video and `asplit/2` for audio when a filtered stream feeds
  several branches. Here we compare a picture with its mirrored version:

      picture = FFix.input("interview.mp4") |> FFix.video(0) |> Filter.scale(w: 640, h: -2)
      [left, right] = Filter.split(picture, outputs: 2)
      comparison = Filter.hstack([left, Filter.hflip(right)])
      FFix.output(comparison, "comparison.mp4") |> FFix.command()

  Each produced filter output must be connected or mapped once in the completed
  command. Connect unwanted branches to a sink such as `nullsink/2` or
  `anullsink/2`, and retain it with the command's `terminals:` option.

  Most filters return one stream. Multi-output filters return an ordered list;
  a sink returns `FFix.Graph.Terminal`. Options can change the result:
  `split(video, outputs: 1)` returns one stream, while `outputs: 2` returns two.
  `ebur128(audio, video: true)` returns `[video, audio]` in that order.

  ## Generate media

  Source filters create their own media and take options only:

      output = Filter.testsrc2(size: "640x360", rate: 30, duration: 2)
      FFix.output(output, "test-pattern.mp4") |> FFix.command()

  Give generated sources a duration, or limit the output with `t:` or a frame
  count, to keep the command finite.

  ## Expressions and filter options

  Use strings for FFmpeg expressions. FFix handles the escaping:

      Filter.volume(voice, volume: 0.5, enable: "between(t,0,3)")

  Timeline-capable filters accept `enable:`. Filters that synchronize several
  inputs may also offer `eof_action:`, `shortest:`, `repeatlast:`, and
  `ts_sync_mode:`; see their option lists below.

  The helper catalog and option reference come from FFmpeg 7.1.5. Check
  `FFix.Discovery` for availability in your installation. FFmpeg supplies
  omitted defaults and performs final value checks when executing.
  Use `filter/4` for another filter name or an explicit output layout.

  See the [FFmpeg filter reference](https://ffmpeg.org/ffmpeg-filters.html) for
  expressions and detailed filter behavior. To parse an existing filtergraph
  or reuse a template, see `FFix.Graph`.
  """
  @moduledoc groups: ["Video", "Audio", "Sources and sinks", "Other filters"]

  alias FFix.Graph.Builder
  alias FFix.Graph.StreamRef
  alias FFix.Graph.Terminal

  @type option :: {atom() | String.t(), String.t() | atom() | number()}

  @doc group: "Other filters"
  @doc """
  Builds a filter using its FFmpeg name, explicit output media, and options.

      FFix.Filter.filter(video, "scale", [:video], w: 1280, h: -2)
      FFix.Filter.filter([background, foreground], "overlay", [:video], x: 10)
      FFix.Filter.filter([], "sine", [:audio], frequency: 440, duration: 2)
      FFix.Filter.filter(video, "nullsink", [])

  Inputs are one stream or a flat ordered list. Use `[]` for a source filter.
  Output media lists `:video`, `:audio`, or `:unknown` for each produced stream.
  An empty list returns a terminal, one element returns a stream, and several
  elements return an ordered stream list.

  This explicit layout lets FFix connect filters whose output count or media
  cannot be determined from the named helper. It must agree with the actual
  FFmpeg options. For example, a two-output split needs both declarations:

      FFix.Filter.filter(video, "split", [:video, :video], outputs: 2)

  Names and option values go directly to FFmpeg, including for known filters.
  Use strings for compound syntax; repeated `:pos` pairs supply positional
  arguments. Escaping is handled during serialization.

  Text filtergraphs do not carry this output-media information, so
  `FFix.Graph.parse!/1` requires filters and layouts it can recognize.
  """
  @spec filter(StreamRef.t() | [StreamRef.t()], atom() | String.t(), [FFix.output_media()], [
          option()
        ]) ::
          StreamRef.t() | [StreamRef.t()] | Terminal.t()
  def filter(inputs, name, output_media, options \\ []),
    do: Builder.filter(inputs, name, output_media, options)

  require FFix.Helpers
  FFix.Helpers.define(:filter)
end
