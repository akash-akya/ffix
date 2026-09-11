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

  `FFix.output/3` and `new/3` take sources first, followed by a
  target and optional CLI options. Both wrap bare sources in unconfigured
  mappings and accept configured mappings directly.

  ## Named Mappings And Deferred Options

  `[main: video_mapping, sound: audio_mapping]` as the sources argument binds
  output-local names without changing track order. Unnamed mappings remain
  supported, including mixed named/unnamed lists. Names are atoms, unique within each output; they are
  not graph export labels and are never inferred from Elixir variable names.

  Encoder, muxer, and raw output option values can be one-argument callbacks.
  They receive a map containing only the named mappings, for example:

      %{main: %{index: 0, specifier: "v:0"}, sound: %{index: 1, specifier: "a:0"}}

  `index` counts all output tracks. `specifier` counts within the media type.
  Unnamed tracks participate in both counts. Both are calculated from the final
  mapping order and restart for each output. The source collection's order is
  preserved, regardless of media type.

  Callbacks run once per supplied option per serialization, after graph and
  mapping validation, not during construction or `FFix.Command.validate!/1`.
  Keep them pure and repeatable: printing a command and then running it performs
  two serializations. Errors in callbacks propagate; a missing map key is a
  normal `KeyError`. Returned values undergo the usual option validation and
  rendering. Named helpers defer their metadata value checks, not name checks.

  An output with callbacks requires every mapping, named or not, to select one
  stream of known video/audio/subtitle/data/attachment media. Broad/raw selectors
  and absolute input indexes cannot supply media-relative callback information.
  Use `FFix.Filter.filter/4` with explicit media for unknown filter outputs.
  No media-file probing occurs.
  Callback results cannot change mappings or return more callbacks. Input/global
  option callbacks are not supported.
  """

  alias FFix.Command
  alias FFix.Command.Mapping
  alias FFix.Options

  @type target :: String.t() | :stdout | {:pipe, non_neg_integer()} | {:url, String.t()}
  @type option :: {atom() | String.t(), term()}

  @type t :: %__MODULE__{
          target: target(),
          mappings: [Mapping.t()],
          muxer: FFix.Muxer.t() | nil,
          options: [option()]
        }

  defstruct [:target, :muxer, mappings: [], options: []]

  @doc "Builds an ordered output declaration without evaluating option callbacks."
  @spec new(Command.binding() | [Command.binding()], target(), [option()]) :: t()
  def new(sources, target, options \\ []) do
    Command.validate_endpoint!(target, :output)
    {configuration, raw_options} = Options.split!(options, [:muxer])
    Command.validate_cli_options!(raw_options)
    sources = List.wrap(sources)

    if sources == [] do
      raise ArgumentError, "output requires at least one source"
    end

    mappings =
      Enum.map(sources, fn source ->
        case source do
          {name, %Mapping{} = mapping} when is_atom(name) and name not in [nil, true, false] ->
            %{mapping | name: name}

          {name, source} when is_atom(name) and name not in [nil, true, false] ->
            %{Mapping.new(source) | name: name}

          %Mapping{} = mapping ->
            mapping

          source ->
            Mapping.new(source)
        end
      end)

    %__MODULE__{
      target: target,
      mappings: mappings,
      muxer: Keyword.get(configuration, :muxer),
      options: raw_options
    }
  end
end
