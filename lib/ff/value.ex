defmodule FF.Value do
  @moduledoc false

  alias FF.Expr

  @type option_spec :: %{optional(:type) => term()} | nil

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

  defp normalize_untyped(%Expr{} = expr), do: expr
  defp normalize_untyped(value) when is_nil(value), do: value
  defp normalize_untyped(value) when is_boolean(value), do: value
  defp normalize_untyped(value) when is_integer(value), do: value
  defp normalize_untyped(value) when is_float(value), do: value
  defp normalize_untyped(value) when is_binary(value), do: value
  defp normalize_untyped(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_untyped(value) when is_list(value), do: Enum.map(value, &normalize_untyped/1)
  defp normalize_untyped(value), do: value

  defp flag_component(value) do
    case normalize_untyped(value) do
      %Expr{source: source} -> source
      value when is_binary(value) -> value
      value when is_integer(value) -> Integer.to_string(value)
      value when is_float(value) -> :erlang.float_to_binary(value, [:compact])
      value when is_boolean(value) -> to_string(value)
      nil -> ""
      value -> to_string(value)
    end
  end
end
