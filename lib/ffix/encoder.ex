defmodule FFix.Encoder do
  @moduledoc """
  Source-taking encoder shortcuts and low-level encoder configuration.

  Named helpers return `FFix.Command.Mapping` values, not filterable streams or
  running encoder instances. Use them after filtering, inside an output callback
  or a one-callback `FFix.command/2` pipeline.

      FFix.Encoder.libx264(video, crf: 18, preset: "slow")

  Each mapping is an independent output use. Reusing a mapping in two output
  declarations does not share encoded packets. Stream copy is expressed with
  `FFix.stream_copy/1`, not an encoder named `"copy"`.

  Named helpers use a recorded metadata baseline, not the installed executable.
  They check option names and basic value shapes, but do not infer defaults or
  guarantee installation, hardware usability, or codec/container compatibility.
  Strings remain open FFmpeg values. Flag lists are normalized to FFmpeg strings.
  `raw: [{"new_option", "value"}]` bypasses metadata checks for individual options.

  `named/3` accepts dynamic registration names without a metadata schema. `new/2`
  constructs a standalone configuration for the lower-level command model.
  All component option names are unscoped and have no leading dash. Values may
  also be callbacks receiving the output's named stream information; see
  `FFix.Command.Output`. Their metadata checks run when the command is serialized.
  """

  alias FFix.Command
  alias FFix.Command.Mapping
  alias FFix.Options

  @type t :: %__MODULE__{name: String.t() | nil, options: [Command.output_av_option()]}
  defstruct [:name, options: []]

  @doc "Builds an unbound configuration without metadata lookup; nil leaves selection to FFmpeg."
  @spec new(String.t() | nil, [Command.output_av_option()]) :: t()
  def new(name, options \\ []) do
    Command.validate_component!(%__MODULE__{name: name, options: options})
  end

  @doc "Maps a source using a dynamic encoder name and unscoped options, without a metadata schema."
  @spec named(Command.source(), String.t(), list()) :: Mapping.t()
  def named(source, name, options \\ []) do
    options = Options.normalize!(options, nil, "#{name} encoder")
    Mapping.new(source, new(name, options))
  end

  require FFix.Helpers
  FFix.Helpers.define(:encoder)
end
