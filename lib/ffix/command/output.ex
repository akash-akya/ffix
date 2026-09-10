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

  ## Named Mappings And Deferred Options

  `sources: [main: video_mapping, sound: audio_mapping]` binds output-local names
  without changing track order. Unnamed mappings remain supported, including
  mixed named/unnamed lists. Names are atoms, unique within each output; they are
  not graph export labels and are never inferred from Elixir variable names.

  Encoder, muxer, and raw output option values can be one-argument callbacks.
  They receive a map containing only the named mappings, for example:

      %{main: %{index: 0, specifier: "v:0"}, sound: %{index: 1, specifier: "a:0"}}

  `index` counts all output tracks. `specifier` counts within the media type.
  Unnamed tracks participate in both counts. Both are calculated from the final
  mapping order and restart for each output. Use `sources:` for explicit ordering;
  the `video:`/`audio:` roles put video first.

  Callbacks run once per supplied option per serialization, after graph and
  mapping validation, not during construction or `FFix.Command.validate!/1`.
  Keep them pure and repeatable: printing a command and then running it performs
  two serializations. Errors in callbacks propagate; a missing map key is a
  normal `KeyError`. Returned values undergo the usual option validation and
  rendering. Named helpers defer their metadata value checks, not name checks.

  An output with callbacks requires every mapping, named or not, to select one
  stream of known audio/video media. Broad/raw selectors and unknown filter
  output media are rejected instead of guessed. Use `FFix.shape/2` for dynamic
  filter shapes that metadata cannot establish. No media-file probing occurs.
  Callback results cannot change mappings or return more callbacks. Input/global
  option callbacks are not supported.
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
