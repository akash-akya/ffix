defmodule FFix.Demuxer do
  @moduledoc """
  Format-specific input shortcuts and low-level demuxer configuration.

  Named helpers return `FFix.Command.Input` declarations and force a format.
  Top-level options configure demuxer AVOptions; put raw input CLI controls in
  `input_options:`. Retain `FFix.input/2` for automatic format detection.

      FFix.Demuxer.rawvideo("frames.rgb",
        video_size: "1920x1080",
        pixel_format: "rgb24",
        framerate: 30
      )

  Helpers and option schemas come from recorded FFmpeg metadata. Aliases such as
  MOV/MP4 refer to the input registration, not the correspondingly named muxers.
  Some input formats are device backends; a helper does not establish hardware
  availability. No discovery or default-option population occurs on construction.

  Strings remain open FFmpeg values, and flag lists are normalized. Use
  `raw: [{"new_option", "value"}]` to bypass metadata checks for selected options,
  or `demux/3` for a dynamic format without a recorded schema. `new/2` builds an
  unbound configuration for `FFix.Command.Input.demuxer`.
  """

  alias FFix.Command
  alias FFix.Command.Input
  alias FFix.Options

  @type t :: %__MODULE__{name: String.t() | nil, options: [Command.av_option()]}
  defstruct [:name, options: []]

  @doc "Builds an unbound demuxer configuration without a metadata schema."
  @spec new(String.t() | nil, [Command.av_option()]) :: t()
  def new(name, options \\ []) do
    Options.validate_component!(%__MODULE__{name: name, options: options})
  end

  @doc "Builds an input for a dynamic demuxer name; extra CLI controls go in input_options."
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
