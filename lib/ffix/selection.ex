defmodule FFix.Selection do
  @moduledoc """
  An unresolved input selection, not a filter pad or an enumerable list.

  Build selections with `FFix.select/3` or a media helper with `:all` or
  `optional: true`. They retain the input declaration without probing it.
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
      %InputRef{input: identity, declaration: %Input{id: identity}, binding: nil}
      when is_reference(identity) ->
        InputRef.normalize_selector!(input_ref.selector)

      _ ->
        raise ArgumentError, "selections require a captured input declaration"
    end

    selection
  end

  @doc "Returns the known media type, or :unknown for whole-input and raw selections."
  @spec media(t()) :: FFix.Graph.StreamRef.media()
  def media(%__MODULE__{input_ref: input_ref}), do: InputRef.media(input_ref.selector)
end
