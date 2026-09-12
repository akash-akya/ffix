defmodule FFix.Command.Input do
  @moduledoc """
  One ffmpeg input declaration, with an identity independent of its filename.

  `new/2` stores raw input CLI options, an optional `FFix.Demuxer`, and indexed
  `FFix.Decoder` configurations. Options render before this input's `-i`.

  `select/3` accepts an absolute stream index, `:all`, or a raw FFmpeg selector
  string. Use `FFix.video/3`, `FFix.audio/3`, or `FFix.subtitle/3` for media-relative
  indexes. Broad, raw, and optional selections return `FFix.Selection`, not a
  filterable reference. Configure inputs before selecting; captured snapshots
  cannot be updated by reassigning a variable.
  """

  alias FFix.Command
  alias FFix.Graph.Builder
  alias FFix.Graph.InputRef
  alias FFix.Graph.StreamRef
  alias FFix.Options
  alias FFix.Selection

  @type source :: String.t() | :stdin | {:pipe, non_neg_integer()} | {:url, String.t()}
  @type option :: {atom() | String.t(), term()}
  @type media :: :video | :audio | :subtitle | :data | :attachment
  @type decoder_selector :: {media(), non_neg_integer()} | {:index, non_neg_integer()}
  @type selector :: non_neg_integer() | :all | String.t()
  @type selection_option :: {:optional, boolean()}

  @type t :: %__MODULE__{
          source: source(),
          id: reference() | nil,
          options: [option()],
          demuxer: FFix.Demuxer.t() | nil,
          decoders: %{decoder_selector() => FFix.Decoder.t()}
        }

  defstruct [:source, :id, :demuxer, options: [], decoders: %{}]

  @doc "Builds an input declaration without probing or evaluating callbacks."
  @spec new(source(), [option()]) :: t()
  def new(source, options \\ []) do
    Command.validate_endpoint!(source, :input)
    {configuration, raw_options} = Options.split!(options, [:demuxer, :decoders])

    if List.keymember?(raw_options, :label, 0) do
      raise ArgumentError, "input labels are not supported; bind named graph inputs explicitly"
    end

    input = %__MODULE__{
      id: make_ref(),
      source: source,
      options: raw_options,
      demuxer: Keyword.get(configuration, :demuxer),
      decoders: Keyword.get(configuration, :decoders, %{})
    }

    Command.validate_input!(input)
  end

  @doc "Selects an absolute input index, all streams, or a raw selector; optional selections may match nothing."
  @spec select(t(), selector(), [selection_option()]) :: StreamRef.t() | Selection.t()
  def select(%__MODULE__{} = input, selector, options \\ []) do
    selector =
      case selector do
        index when is_integer(index) and index >= 0 ->
          {:index, index}

        :all ->
          :all

        raw when is_binary(raw) ->
          {:raw, raw}

        other ->
          raise ArgumentError,
                "invalid input selector: #{inspect(other)}; use an absolute index, :all, or a raw string"
      end

    selection(input, selector, selection_options!(options, [:optional]))
  end

  @doc false
  def select_media(%__MODULE__{} = input, media, index, options \\ []) do
    allowed = if media == :video, do: [:optional, :attached_pictures], else: [:optional]
    options = selection_options!(options, allowed)

    media =
      if media == :video and not Keyword.get(options, :attached_pictures, true),
        do: :video_only,
        else: media

    selection(input, {media, index}, options)
  end

  defp selection(input, selector, options) do
    selector = InputRef.normalize_selector!(selector)
    optional = Keyword.get(options, :optional, false)

    if InputRef.single?(selector) and not optional,
      do: Builder.input(input, selector),
      else: Selection.new(input, selector, optional)
  end

  defp selection_options!(options, allowed) do
    {controls, unknown} = Options.split!(options, allowed)
    if unknown != [], do: raise(ArgumentError, "unknown selection options: #{inspect(unknown)}")

    Enum.each(controls, fn {name, value} ->
      unless is_boolean(value), do: raise(ArgumentError, "#{name} must be a boolean")
    end)

    controls
  end
end
