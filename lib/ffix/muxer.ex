defmodule FFix.Muxer do
  @moduledoc """
  Format-specific output shortcuts and low-level muxer configuration.

  Named helpers return `FFix.Command.Output` declarations. Pass sources first,
  then the target and optional muxer AVOptions. Put raw file-level CLI controls
  in `output_options:`.

      FFix.Muxer.mp4([FFix.Encoder.libx264(video, crf: 18)], "out.mp4",
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

  `mux/4` handles dynamic formats without a metadata schema. `new/2` builds a
  standalone muxer configuration; a nil name leaves format selection to FFmpeg.

  Name mappings with `[main: mapping, sound: audio_mapping]` as the sources argument.
  Option values may be callbacks such as `fn streams -> streams.main.specifier end`.
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
  @spec mux(Command.binding() | [Command.binding()], String.t(), Output.target(), list()) ::
          Output.t()
  def mux(sources, name, target, options \\ []),
    do: build_output(sources, name, target, options, nil)

  defp build_output(sources, name, target, options, schema) do
    {controls, options} = Options.split!(options, [:output_options])
    output_options = Keyword.get(controls, :output_options, [])
    {_special, output_options} = Options.split!(output_options, [])
    muxer_options = Options.normalize!(options, schema, "#{name} muxer")
    output = Command.output(sources, target)
    %{output | muxer: new(name, muxer_options), options: output_options}
  end

  require FFix.Helpers
  FFix.Helpers.define(:muxer)
end
