defmodule FFix.Muxer do
  @moduledoc """
  Package output streams into a file or streaming format.

  A muxer writes the container. Choose encoding separately with `FFix.Encoder`,
  or keep the existing encoded streams with `FFix.stream_copy/1`.

  ## MP4 for download and playback

      alias FFix.{Encoder, Muxer}
      source = FFix.input("interview.mov")

      output =
        Muxer.mp4(
          [Encoder.libx264(FFix.video(source, 0)), Encoder.aac(FFix.audio(source, 0))],
          "interview.mp4",
          movflags: [:faststart],
          output_options: [t: 30]
        )

      FFix.command(output)

  `movflags` configures the MP4 muxer. `output_options: [t: 30]` limits the output
  to 30 seconds. Keeping those option lists separate makes their scope clear.
  See `FFix.Command` for general FFmpeg option syntax.

  A named helper selects its format regardless of the filename. Use
  `FFix.output/3` when FFmpeg should choose the format from the target instead.
  `new/2` provides a standalone muxer configuration and `mux/4` accepts other
  FFmpeg format names.

  ## Segments and playlists

  One output declaration can write a set of files. This creates an HLS playlist
  and its media segments:

      source = FFix.input("interview.mp4")
      video = FFix.Encoder.libx264(FFix.video(source, 0), b: "2M")
      audio = FFix.Encoder.aac(FFix.audio(source, 0), b: "128k")

      output = FFix.Muxer.hls([video, audio], "hls/index.m3u8", hls_time: 4)
      FFix.command(output)

  Create the `hls` directory before running the command. HLS segments normally
  start at keyframes, so `hls_time` is a target duration. For multiple renditions
  sharing audio, see the named-mapping example in `FFix.Command.Output`.

  Helpers document options from the recorded FFmpeg reference. Use `raw:` for
  newer option names, as described in `FFix.Encoder`. Available formats and codec
  compatibility depend on the FFmpeg build and destination container.

  See the [FFmpeg format reference](https://ffmpeg.org/ffmpeg-formats.html) for
  muxer options and format-specific requirements.
  """

  alias FFix.Command
  alias FFix.Command.Output
  alias FFix.Options

  @type t :: %__MODULE__{name: String.t() | nil, options: [Command.output_av_option()]}
  defstruct [:name, options: []]

  @doc """
  Builds a muxer configuration for the `muxer:` option of `FFix.output/3`.

      muxer = FFix.Muxer.new("mp4", movflags: "faststart")
      FFix.output(video, "video.mp4", muxer: muxer)

  Use a `nil` name to let FFmpeg select the format while applying the options.
  """
  @spec new(String.t() | nil, [Command.output_av_option()]) :: t()
  def new(name, options \\ []) do
    Options.validate_component!(%__MODULE__{name: name, options: options})
  end

  @doc """
  Declares an output using an FFmpeg format name and its options.

      FFix.Muxer.mux(audio, "flac", "recording.flac")

  Format names and options are passed to FFmpeg. Place general output controls,
  such as a duration limit, in `output_options:`.
  """
  @spec mux(Command.binding() | [Command.binding()], String.t(), Output.target(), list()) ::
          Output.t()
  def mux(sources, name, target, options \\ []),
    do: build_output(sources, name, target, options, nil)

  defp build_output(sources, name, target, options, schema) do
    {controls, options} = Options.split!(options, [:output_options])
    output_options = Keyword.get(controls, :output_options, [])
    {_special, output_options} = Options.split!(output_options, [])
    muxer_options = Options.normalize!(options, schema, "#{name} muxer")
    Output.new(sources, target, [{:muxer, new(name, muxer_options)} | output_options])
  end

  require FFix.Helpers
  FFix.Helpers.define(:muxer)
end
