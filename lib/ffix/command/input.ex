defmodule FFix.Command.Input do
  @moduledoc """
  One ffmpeg input declaration, with an identity independent of its filename.

  `new/2` stores raw input CLI options, an optional `FFix.Demuxer`, and indexed
  `FFix.Decoder` configurations. Options render before this input's `-i`.

  `select/2` returns a filterable or directly mappable stream that captures the
  complete declaration. Configure decoding before selecting streams: changing
  an input later does not mutate existing references. Conflicting snapshots of
  the same declaration cannot be used in one command.

      input = FFix.Command.Input.new("input.mp4", ss: "00:00:03")
      FFix.Command.Input.select(input, {:video, 0})
      FFix.Command.Input.select(input, {:audio, :all})

  Selectors are `:all`, `{media, index}`, `{media, :all}`, `{:index, index}` for
  an absolute stream index, and `{:raw, selector}` for an FFmpeg selector string.
  Media types are `:video`, `:audio`, `:subtitle`, `:data`, and `:attachment`.
  Broad and raw selections are not assumed to select exactly one stream.
  """

  alias FFix.Command
  alias FFix.Graph.Builder
  alias FFix.Graph.InputRef
  alias FFix.Graph.StreamRef
  alias FFix.Options

  @type source :: String.t() | :stdin | {:pipe, non_neg_integer()} | {:url, String.t()}
  @type option :: {atom() | String.t(), term()}
  @type media :: :video | :audio | :subtitle | :data | :attachment
  @type decoder_selector :: {media(), non_neg_integer()} | {:index, non_neg_integer()}
  @type selector ::
          :all
          | {media(), non_neg_integer() | :all}
          | {:index, non_neg_integer()}
          | {:raw, String.t()}

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

  @doc "Selects streams while capturing this input's complete configuration."
  @spec select(t(), selector()) :: StreamRef.t()
  def select(%__MODULE__{} = input, selector) do
    case selector do
      :all ->
        :ok

      {_kind, _value} ->
        InputRef.normalize_selector!(selector)

      _other ->
        raise ArgumentError,
              "invalid input selector: #{inspect(selector)}; use :all or an explicit indexed, media-wide, or raw selector"
    end

    Builder.input(input, selector)
  end
end
