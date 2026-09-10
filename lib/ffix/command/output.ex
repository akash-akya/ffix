defmodule FFix.Command.Output do
  @moduledoc """
  One ffmpeg output declaration.

  `mappings` is an ordered list of `FFix.Command.Mapping` values. Each mapping
  selects a source and optionally configures encoding or stream copy. `muxer`
  configures the output container independently of those mappings.

  `options` retains raw output CLI options. Do not mix raw codec selections or
  matching codec option names with structured encoding, or raw format selections
  or matching format option names with a structured muxer. These combinations
  are rejected rather than silently overridden.

  Maps, encoding configuration, muxer configuration, and raw options are rendered
  before the target. Output-stream indexes start at zero for each output.

  `FFix.Command.output/3` wraps bare sources in unconfigured mappings and also
  accepts mapping values directly. The public `FFix.output/2` helper still accepts
  `video:`, `audio:`, or an explicitly ordered `sources:` list.
  """

  alias FFix.Command.Mapping

  @type target :: String.t() | :stdout | {:pipe, non_neg_integer()} | {:url, String.t()}
  @type option :: {atom() | String.t(), term()}

  @type t :: %__MODULE__{
          target: target(),
          mappings: [Mapping.t()],
          muxer: FFix.Muxer.t() | nil,
          options: [option()]
        }

  defstruct [:target, :muxer, mappings: [], options: []]
end
