defmodule FFix.Options do
  @moduledoc false

  @integer_types [:int, :int64, :uint64, :unsigned, :flags]
  @number_types [:float, :double, :duration, :rational, :video_rate]
  @string_types [
    :string,
    :binary,
    :image_size,
    :pix_fmt,
    :sample_fmt,
    :channel_layout,
    :dictionary,
    :color
  ]

  @spec split!(list(), [atom()]) :: {list(), list()}
  def split!(options, keys) do
    unless is_list(options) do
      raise ArgumentError, "options must be a list of name/value pairs"
    end

    Enum.each(options, fn option ->
      case option do
        {key, _value} when is_atom(key) or is_binary(key) -> :ok
        other -> raise ArgumentError, "invalid option: #{inspect(other)}"
      end
    end)

    {special, remaining} = Enum.split_with(options, fn {key, _value} -> key in keys end)
    special_names = Enum.map(special, &elem(&1, 0))

    if length(special_names) != length(Enum.uniq(special_names)) do
      raise ArgumentError, "duplicate option; specify each of #{inspect(keys)} at most once"
    end

    {special, remaining}
  end

  @doc false
  def normalize!(options, schema, context) do
    {escape, checked} = split!(options, [:raw])
    raw = Keyword.get(escape, :raw, [])
    {_special, raw} = split!(raw, [])

    checked =
      Enum.map(checked, fn {key, value} ->
        name = to_string(key)

        case schema do
          nil ->
            {name, value}

          schema ->
            {name, normalize_value!(value, option_spec!(schema, name, context), name, context)}
        end
      end)

    raw = Enum.map(raw, fn {key, value} -> {to_string(key), value} end)
    result = checked ++ raw
    names = Enum.map(result, &elem(&1, 0))

    if length(names) != length(Enum.uniq(names)) do
      raise ArgumentError, "duplicate option in #{context}; specify each option once"
    end

    result
  end

  defp option_spec!(schema, name, context) do
    case Map.fetch(schema, name) do
      {:ok, variants} -> variants
      :error -> raise ArgumentError, unknown_option_message(schema, name, context)
    end
  end

  defp unknown_option_message(schema, name, context) do
    nearest =
      schema
      |> Map.keys()
      |> Enum.sort()
      |> Enum.max_by(&String.jaro_distance(name, &1), fn -> nil end)

    suggestion =
      case nearest do
        nil ->
          ""

        candidate ->
          case String.jaro_distance(name, candidate) >= 0.8 do
            true -> " Did you mean #{inspect(candidate)}?"
            false -> ""
          end
      end

    "unknown #{context} option #{inspect(name)}." <>
      suggestion <>
      " Use raw: [{name, value}] for options outside the recorded schema."
  end

  defp normalize_value!(value, variants, name, context) do
    case Enum.find(variants, &accepts?(&1, value)) do
      nil ->
        raise ArgumentError,
              "invalid value #{inspect(value)} for #{context} option #{inspect(name)}; use an FFmpeg string for expressions or compound values"

      %{type: :flags} when is_list(value) ->
        case value do
          [] -> "0"
          values -> Enum.map_join(values, "+", &to_string/1)
        end

      _variant when is_atom(value) and not is_boolean(value) ->
        Atom.to_string(value)

      _variant ->
        value
    end
  end

  defp accepts?(%{type: type, constants: constants}, value) do
    case value do
      nil ->
        false

      value when is_binary(value) ->
        true

      value when is_boolean(value) ->
        type == :boolean or match?({:unknown, _name}, type)

      value when is_integer(value) ->
        type in (@integer_types ++ @number_types) or match?({:unknown, _name}, type)

      value when is_float(value) ->
        type in @number_types or match?({:unknown, _name}, type)

      value when is_atom(value) ->
        type in @string_types or to_string(value) in constants or
          (type == :boolean and value == :auto) or match?({:unknown, _name}, type)

      values when is_list(values) ->
        type == :flags and
          Enum.all?(values, fn flag ->
            is_binary(flag) or (is_atom(flag) and to_string(flag) in constants)
          end)

      _other ->
        false
    end
  end
end
