defmodule FFix.Value do
  @moduledoc false

  @type option_spec :: %{optional(:type) => term()} | nil

  # FFmpeg duration options accept decimal notation, not scientific notation.
  @spec float_to_string(float()) :: String.t()
  def float_to_string(value) when is_float(value) do
    decimal =
      case String.split(Float.to_string(value), "e") do
        [decimal] ->
          decimal

        [mantissa, exponent] ->
          sign = if String.starts_with?(mantissa, "-"), do: "-", else: ""
          [whole, fraction] = mantissa |> String.trim_leading("-") |> String.split(".")
          digits = whole <> fraction
          point = byte_size(whole) + String.to_integer(exponent)

          decimal =
            cond do
              point <= 0 ->
                "0." <> String.duplicate("0", -point) <> digits

              point >= byte_size(digits) ->
                digits <> String.duplicate("0", point - byte_size(digits))

              true ->
                {left, right} = String.split_at(digits, point)
                left <> "." <> right
            end

          sign <> decimal
      end

    if String.contains?(decimal, "."),
      do: decimal |> String.trim_trailing("0") |> String.trim_trailing("."),
      else: decimal
  end

  @spec normalize(term(), option_spec()) :: term()
  def normalize(value, %{type: {:array, type}} = spec) when is_list(value) do
    item_spec = Map.put(spec, :type, type)
    Enum.map(value, &normalize(&1, item_spec))
  end

  def normalize(value, %{type: {:array, type}} = spec) do
    normalize(value, Map.put(spec, :type, type))
  end

  def normalize(value, %{type: :flags}), do: normalize_flags(value)
  def normalize(value, %{type: :int}), do: normalize_integer(value)
  def normalize(value, %{type: :int64}), do: normalize_integer(value)
  def normalize(value, _spec), do: normalize_untyped(value)

  defp normalize_flags(value) when is_list(value) do
    Enum.map_join(value, "+", &flag_component/1)
  end

  defp normalize_flags(value), do: normalize_integer(value)

  defp normalize_integer(value) do
    case normalize_untyped(value) do
      value when is_binary(value) ->
        case Integer.parse(value) do
          {integer, ""} -> integer
          _ -> value
        end

      value ->
        value
    end
  end

  defp normalize_untyped(value) when is_nil(value), do: value
  defp normalize_untyped(value) when is_boolean(value), do: value
  defp normalize_untyped(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_untyped(value) when is_list(value), do: Enum.map(value, &normalize_untyped/1)
  defp normalize_untyped(value), do: value

  defp flag_component(value) do
    case normalize_untyped(value) do
      value when is_binary(value) -> value
      value when is_integer(value) -> Integer.to_string(value)
      value when is_float(value) -> float_to_string(value)
      value when is_boolean(value) -> to_string(value)
      nil -> ""
      value -> to_string(value)
    end
  end
end
