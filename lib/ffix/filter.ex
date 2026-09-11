defmodule FFix.Filter do
  @moduledoc """
  Generated helpers for ffmpeg filters.

  Each named function mirrors one filter in the recorded FFmpeg metadata snapshot.
  Compilation and graph construction do not run FFmpeg. Function names and option
  keys stay close to ffmpeg. Arguments are `FFix.Graph.StreamRef` values; the final
  argument is a keyword list of ffmpeg filter options.

      video
      |> scale(w: 1280, h: -1)
      |> fps(fps: 30)

  Zero outputs return `FFix.Graph.Terminal`, one returns `FFix.Graph.StreamRef`,
  and multiple outputs always return an ordered list:

      [left, right] = split(video, outputs: 2)
      stacked = hstack([left, hflip(right)])

  Supported option-dependent shapes follow their effective options, including
  aliases and positional values. For example, `ebur128(audio_in, video: true)`
  returns `[video, audio]`, while video disabled returns just the audio reference.
  Unresolved shapes raise rather than guessing a pad count or media type.

  Use `filter/4` to supply a filter name, explicit output media, and options
  without metadata lookup.

  Reported defaults/ranges are metadata, not emitted defaults or complete
  validation. Plain strings carry FFmpeg expressions and compound syntax;
  repeated `:pos` options supply positional arguments.

  Timeline-capable filters accept ffmpeg's implicit `enable:` option. Filters
  backed by ffmpeg framesync also accept the common `eof_action:`, `shortest:`,
  `repeatlast:`, and `ts_sync_mode:` options.
  """
  @moduledoc groups: [
               "Generic filters",
               "Source filters",
               "Video filters",
               "Audio filters",
               "Audio/video filters",
               "Multi-stream filters",
               "Sink filters",
               "Other filters"
             ]

  alias FFix.Graph.Builder
  alias FFix.Graph.StreamRef
  alias FFix.Graph.Terminal

  @type option :: {atom() | String.t(), String.t() | atom() | number()}

  @doc group: "Generic filters"
  @doc """
  Builds a filter from explicit inputs, a name, output media, and optional values.

      video |> FFix.Filter.filter("scale", [:video], w: 1280, h: -2)
      FFix.Filter.filter([background, foreground], "overlay", [:video], x: 10)
      FFix.Filter.filter([], "vendor_source", [:audio], frequency: 440)
      FFix.Filter.filter(video, "nullsink", [])

  Inputs are a stream reference or a flat ordered list. Use `[]` for source
  filters. Output media is an ordered list of `:video`, `:audio`, or `:unknown`.
  Zero outputs return a terminal, one returns a reference, and multiple outputs
  return a list. This shape is graph information, not an emitted FFmpeg option;
  the caller must ensure it agrees with the actual filter configuration.

  Names and options pass through without registry or option-schema lookup, even
  for known filters. No defaults, flags, or array delimiters are inferred. Use
  scalar values or strings for compound syntax. Repeated `:pos`
  pairs supply positional arguments. Values are escaped during serialization.

  Named helpers retain metadata checks and shape inference. `FFix.Graph.parse!/1`
  still requires known filters: serialized text does not preserve media shapes
  supplied to this function.
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
