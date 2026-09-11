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

  @spec normalize_selector!(term()) :: selector()
  def normalize_selector!(selector) when selector in [:input, :video, :audio], do: selector

  def normalize_selector!({media, index} = selector)
      when media in [:video, :audio] and is_integer(index) and index >= 0,
      do: selector

  def normalize_selector!({:raw, value} = selector) when is_binary(value) and value != "" do
    if String.contains?(value, <<0>>),
      do: raise(ArgumentError, "input selector cannot contain NUL")

    selector
  end

  def normalize_selector!(selector),
    do: raise(ArgumentError, "invalid input selector: #{inspect(selector)}")

  @spec media(selector()) :: :audio | :video | :unknown
  def media(:video), do: :video
  def media(:audio), do: :audio
  def media({:video, _index}), do: :video
  def media({:audio, _index}), do: :audio
  def media(_selector), do: :unknown
end
