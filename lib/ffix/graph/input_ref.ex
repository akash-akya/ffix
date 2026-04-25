defmodule FFix.Graph.InputRef do
  @moduledoc false

  @type input_id :: non_neg_integer() | String.t() | reference()

  @type selector ::
          :input
          | :video
          | :audio
          | {:video, non_neg_integer()}
          | {:audio, non_neg_integer()}
          | {:raw, String.t()}

  @type t :: %__MODULE__{
          input: input_id(),
          selector: selector()
        }

  defstruct [:input, :selector]

  @spec normalize_input_id!(non_neg_integer() | atom() | String.t() | reference()) :: input_id()
  def normalize_input_id!(input) when is_integer(input) and input >= 0, do: input
  def normalize_input_id!(input) when is_reference(input), do: input
  def normalize_input_id!(input) when is_atom(input), do: Atom.to_string(input)
  def normalize_input_id!(input) when is_binary(input) and input != "", do: input

  def normalize_input_id!(input) do
    raise ArgumentError,
          "input id must be a non-negative integer, reference, atom, or non-empty string, got: #{inspect(input)}"
  end
end
