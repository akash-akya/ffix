defmodule FFix.Demuxer do
  @moduledoc """
  Choose how FFmpeg reads an input format.

  For ordinary media files, start with `FFix.input/2`: FFmpeg usually detects
  their format. Select a demuxer when the input needs extra information, such as
  the dimensions of raw video or the sample rate of raw audio.

  ## Read raw frames

      alias FFix.{Demuxer, Encoder, Muxer}

      source =
        Demuxer.rawvideo("frames.rgb",
          video_size: "1920x1080",
          pixel_format: "rgb24",
          framerate: 30
        )

      output = source |> FFix.video(0) |> Encoder.libx264() |> Muxer.mp4("frames.mp4")
      FFix.command(output)

  A raw frame file carries no header describing its size or pixel layout, so
  these options must match the data. The demuxer returns an input declaration;
  select its streams in the same way as any other input.

  ## Input controls

  Pass format-specific options directly to the helper. General input controls,
  such as seeking, go in `input_options:`:

      FFix.Demuxer.mov("interview.mp4", input_options: [ss: 30])

  `mov/2` reads the MOV/MP4 family of containers. Input and output format names
  can differ; use `FFix.Muxer` to choose the destination format.

  Use `demux/3` for other format names, including FFmpeg input devices. Named
  helpers use the recorded option reference; `raw:` accepts newer option names
  as described in `FFix.Encoder`. Check `FFix.Discovery` for the formats and device
  backends available in your build.

  See the [FFmpeg demuxer reference](https://ffmpeg.org/ffmpeg-formats.html#Demuxers).
  """

  alias FFix.Command
  alias FFix.Command.Input
  alias FFix.Options

  @type t :: %__MODULE__{name: String.t() | nil, options: [Command.av_option()]}
  defstruct [:name, options: []]

  @doc """
  Builds a demuxer configuration for the `demuxer:` option of `FFix.input/2`.

      format = FFix.Demuxer.new("rawvideo", video_size: "640x480", pixel_format: "rgb24")
      FFix.input("frames.rgb", demuxer: format)

  A `nil` name keeps automatic format detection while applying the options.
  """
  @spec new(String.t() | nil, [Command.av_option()]) :: t()
  def new(name, options \\ []) do
    Options.validate_component!(%__MODULE__{name: name, options: options})
  end

  @doc """
  Declares an input using an FFmpeg format name and its options.

      FFix.Demuxer.demux("recording.pcm", "s16le", sample_rate: 48000)

  Names and options are passed to FFmpeg. General input controls go in
  `input_options:`. Use `FFix.Decoder` for decoding settings after declaring the input.
  """
  @spec demux(Input.source(), String.t(), list()) :: Input.t()
  def demux(source, name, options \\ []), do: build_input(source, name, options, nil)

  defp build_input(source, name, options, schema) do
    {bindings, options} = Options.split!(options, [:input_options])
    input_options = Keyword.get(bindings, :input_options, [])
    {_special, input_options} = Options.split!(input_options, [])
    demuxer_options = Options.normalize!(options, schema, "#{name} demuxer")
    Input.new(source, [{:demuxer, new(name, demuxer_options)} | input_options])
  end

  require FFix.Helpers
  FFix.Helpers.define(:demuxer)
end
