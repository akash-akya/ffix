defmodule FFix.Selection do
  @moduledoc """
  A query selecting input streams for an output.

  Media helpers return selections for `:all` or `optional: true`.
  `FFix.select/3` also returns them for string stream specifiers. Pass a
  selection to `FFix.output/3`, `FFix.Encoder`, or `FFix.stream_copy/1`.

  FFmpeg determines the matching tracks when the command runs. For a filter
  input, select a required index such as `FFix.audio(source, 0)` instead.
  See `FFix.Command.Input` for examples and `FFix.Command.Mapping` for
  applying encoding settings to multiple selected tracks.
  """

  alias FFix.Command.Input
  alias FFix.Graph.InputRef

  @opaque t :: %__MODULE__{input_ref: term(), optional: boolean()}
  defstruct [:input_ref, optional: false]

  @doc false
  def new(%Input{} = input, selector, optional) do
    validate!(%__MODULE__{input_ref: InputRef.new(input, selector), optional: optional})
  end

  @doc false
  def validate!(%__MODULE__{input_ref: input_ref, optional: optional} = selection) do
    unless is_boolean(optional), do: raise(ArgumentError, "optional must be a boolean")

    case input_ref do
      %InputRef{input: identity, declaration: %Input{id: identity}}
      when is_reference(identity) ->
        InputRef.normalize_selector!(input_ref.selector)

      _ ->
        raise ArgumentError, "selections require a captured input declaration"
    end

    selection
  end

  @doc "Returns the selected media type, or `:unknown` for whole-input and string queries."
  @spec media(t()) :: FFix.Graph.StreamRef.media()
  def media(%__MODULE__{input_ref: input_ref}), do: InputRef.media(input_ref.selector)
end
