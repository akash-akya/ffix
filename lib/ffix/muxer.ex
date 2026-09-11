defmodule FFix.Muxer do
  @moduledoc """
  Format-specific output shortcuts and low-level muxer configuration.

  Named helpers return `FFix.Command.Output` declarations. Use `video:`, `audio:`,
  or ordered `sources:` bindings as in `FFix.output/2`. Other top-level options
  configure the muxer. Put raw file-level CLI controls in `output_options:`.

      FFix.Muxer.mp4("out.mp4",
        video: FFix.Encoder.libx264(video, crf: 18),
        movflags: [:faststart],
        output_options: [t: 10]
      )

  The helper forces its named format regardless of the target's extension.
  A declaration can write multiple files, as with HLS or segmenting muxers.
  Keep `FFix.output/2` for automatic format selection or independent muxer values.

  Helpers validate option names and basic values using recorded metadata, not
  live discovery. No reported defaults are emitted. Strings remain open FFmpeg
  values; flag lists are normalized. `raw: [{"new_option", "value"}]` skips
  metadata checks for particular options, not command-structure validation.

  `named/3` handles dynamic formats without a metadata schema. `new/2` builds a
  standalone muxer configuration; a nil name leaves format selection to FFmpeg.

  Name mappings with `sources: [main: mapping, sound: audio_mapping]`. Option
  values may be callbacks such as `fn streams -> streams.main.specifier end`.
  They receive final output-local indexes during serialization, with no special
  treatment of any FFmpeg option name. See `FFix.Command.Output` for the contract.
  """

  alias FFix.Command
  alias FFix.Command.Output
  alias FFix.Options

  @type t :: %__MODULE__{name: String.t() | nil, options: [Command.output_av_option()]}
  defstruct [:name, options: []]

  @doc "Builds an unbound muxer configuration without a metadata schema."
  @spec new(String.t() | nil, [Command.output_av_option()]) :: t()
  def new(name, options \\ []) do
    Command.validate_component!(%__MODULE__{name: name, options: options})
  end

  @doc "Builds an output for a dynamic muxer name; extra CLI controls go in output_options."
  @spec named(Output.target(), String.t(), list()) :: Output.t()
  def named(target, name, options), do: build_output(target, name, options, nil)

  defp build_output(target, name, options, schema) do
    {bindings, options} = Options.split!(options, [:video, :audio, :sources, :output_options])
    output_options = Keyword.get(bindings, :output_options, [])
    {_special, output_options} = Options.split!(output_options, [])
    muxer_options = Options.normalize!(options, schema, "#{name} muxer")
    output = FFix.output(target, Keyword.drop(bindings, [:output_options]))
    %{output | muxer: new(name, muxer_options), options: output_options}
  end

  require FFix.Helpers
  FFix.Helpers.define(:muxer)
end
