defmodule FFix.Encoder do
  @moduledoc """
  Choose how output streams are compressed.

  Apply an encoder to an input stream or to the end of a filter pipeline, then
  pass the result to `FFix.output/3` or a `FFix.Muxer` helper.

  ## Video quality

  `libx264/2` encodes H.264 video. CRF is a quality setting: lower values give
  higher quality and usually larger files. Start around 23 and compare a short
  sample. The preset trades encoding time for compression efficiency.

      alias FFix.{Encoder, Muxer}

      command =
        FFix.input("interview.mp4")
        |> FFix.video(0)
        |> Encoder.libx264(crf: 23, preset: "medium")
        |> Muxer.mp4("interview-video.mp4")
        |> FFix.command()

  For a bitrate-based delivery target, use `b: "2M"`. Options such as `maxrate`
  and `bufsize` give finer control over bitrate variation; consult the selected
  encoder's reference before combining rate-control settings.

  ## Audio and multiple tracks

      source = FFix.input("interview.mp4")
      audio = source |> FFix.audio(:all) |> Encoder.aac(b: "128k")
      output = FFix.output(audio, "audio.m4a")

  This applies AAC encoding to each selected audio track. Use explicit indexes
  when tracks need different settings. `FFix.Command.Mapping` explains how
  encoding settings follow mapping order, including selections of several tracks.

  Apply filters before the encoder. To keep existing encoded media, use
  `FFix.stream_copy/1`. Reusing an encoder configuration in several mappings
  requests a separate encode for each output use.

  ## Options

  Write option names without a leading dash or a stream suffix:
  `b: "128k"`, rather than `"-b:a:0"`. FFix adds the correct output-stream scope.
  Strings carry FFmpeg expressions and compound values; supported flag options
  also accept lists of names. Output options can use callbacks to refer to named
  streams; see `FFix.Command.Output`.

  Named helpers check options against a reference recorded from FFmpeg 7.1.5.
  FFmpeg supplies defaults for omitted options. Check `FFix.Discovery` when an
  encoder needs to be available in a particular deployment.

  Use `encode/3` for other encoders. For a named helper's newer options,
  `raw: [{name, value}]` skips the recorded option lookup while retaining the
  usual value and command-option checks.

  See the [FFmpeg codec reference](https://ffmpeg.org/ffmpeg-codecs.html) and
  [H.264 encoding guide](https://trac.ffmpeg.org/wiki/Encode/H.264) for more detail.
  """

  alias FFix.Command
  alias FFix.Command.Mapping
  alias FFix.Options

  @type t :: %__MODULE__{name: String.t() | nil, options: [Command.output_av_option()]}
  defstruct [:name, options: []]

  @doc """
  Builds a reusable encoder configuration for `FFix.Command.Mapping.new/2`.

      encoder = FFix.Encoder.new("libx264", crf: 20)
      FFix.Command.Mapping.new(video, encoder)

  A `nil` name lets FFmpeg choose the encoder while applying the supplied options.
  For a pipeline, prefer a named helper or `encode/3`.
  """
  @spec new(String.t() | nil, [Command.output_av_option()]) :: t()
  def new(name, options \\ []) do
    Options.validate_component!(%__MODULE__{name: name, options: options})
  end

  @doc """
  Encodes a source using an FFmpeg codec or encoder name and its options.

      source = FFix.input("recording.wav")
      audio = FFix.Encoder.encode(FFix.audio(source, 0), "flac", compression_level: 8)
      FFix.output(audio, "recording.flac")

  Names and options are passed to FFmpeg. A codec name such as `"h264"` lets
  FFmpeg select an implementation. Use `"libx264"` or `libx264/2` when you need
  that implementation and its particular options.
  """
  @spec encode(Command.source(), String.t(), list()) :: Mapping.t()
  def encode(source, name, options \\ []) do
    options = Options.normalize!(options, nil, "#{name} encoder")
    Mapping.new(source, new(name, options))
  end

  @doc false
  def validate_source_media!(%FFix.Selection{} = selection, expected),
    do: validate_source_media!(%{media: FFix.Selection.media(selection)}, expected)

  def validate_source_media!(%{media: media}, expected)
      when media != :unknown and expected != nil and media != expected do
    raise ArgumentError, "encoder expects #{expected} source, got: #{media}"
  end

  def validate_source_media!(_source, _expected), do: :ok

  require FFix.Helpers
  FFix.Helpers.define(:encoder)
end
