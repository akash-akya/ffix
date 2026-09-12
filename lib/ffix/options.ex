defmodule FFix.Options do
  @moduledoc false

  alias FFix.{Encoder, Muxer}

  @codec_controls ~w(c codec vcodec acodec scodec dcodec)
  @graph_controls ~w(filter_complex filter_complex_script lavfi)
  @mapping_controls ~w(i map map_channel attach vn an sn dn) ++ @graph_controls

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
            variants = option_spec!(schema, name, context)

            normalized =
              if is_function(value, 1) do
                fn streams -> normalize_value!(value.(streams), variants, name, context) end
              else
                normalize_value!(value, variants, name, context)
              end

            {name, normalized}
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

  @doc false
  def resolve!(options, streams) do
    Enum.map(options, fn {name, value} ->
      resolved =
        if is_function(value, 1) do
          value.(streams)
        else
          value
        end

      if is_function(resolved) do
        raise ArgumentError,
              "option callback #{inspect(name)} must return a value, not another function"
      end

      {name, resolved}
    end)
  end

  def validate_endpoint!(endpoint, direction) do
    valid? =
      case endpoint do
        value when is_binary(value) -> value != "" and not String.contains?(value, <<0>>)
        {:url, value} when is_binary(value) -> value != "" and not String.contains?(value, <<0>>)
        {:pipe, descriptor} when is_integer(descriptor) and descriptor >= 0 -> true
        :stdin -> direction == :input
        :stdout -> direction == :output
        _other -> false
      end

    unless valid? do
      raise ArgumentError, "invalid #{direction} source/target: #{inspect(endpoint)}"
    end

    endpoint
  end

  def validate_cli!(options, callbacks? \\ false) do
    {_special, options} = split!(options, [])

    Enum.each(options, fn {key, value} ->
      name = to_string(key)

      if name == "" or String.starts_with?(name, "-") or
           String.contains?(name, [" ", "\t", "\n", "\r", <<0>>]) do
        raise ArgumentError, "invalid CLI option name: #{inspect(name)}"
      end

      if is_function(value) do
        validate_callback!(name, value, callbacks?)
      else
        validate_cli_value!(value)
      end
    end)
  end

  def validate_component!(component) do
    unless is_nil(component.name) or
             (is_binary(component.name) and component.name != "" and
                not String.contains?(component.name, <<0>>)) do
      raise ArgumentError, "component name must be a non-empty string or nil"
    end

    if match?(%Encoder{name: "copy"}, component) do
      raise ArgumentError, "copy is a mapping mode; use encoding: :copy"
    end

    unless is_list(component.options) do
      raise ArgumentError, "component options must be an ordered list of name/value pairs"
    end

    callbacks? = is_struct(component, Encoder) or is_struct(component, Muxer)

    names =
      Enum.map(component.options, fn
        {key, value} when is_atom(key) or is_binary(key) ->
          name = to_string(key)
          validate_av_option!(name, value, callbacks?)
          name

        other ->
          raise ArgumentError, "invalid component option: #{inspect(other)}"
      end)

    if length(names) != length(Enum.uniq(names)) do
      raise ArgumentError, "duplicate component option; specify each option once"
    end

    component
  end

  def callbacks?(%{options: options}), do: callbacks?(options)
  def callbacks?(unconfigured) when unconfigured in [nil, :copy], do: false
  def callbacks?(options), do: Enum.any?(options, fn {_name, value} -> is_function(value) end)

  def reject_conflicts!(options, role, components \\ []) do
    {controls, owner} =
      case role do
        :encoding -> {@codec_controls ++ @mapping_controls, "structured encoding"}
        :decoding -> {@codec_controls, "structured decoding"}
        :muxer -> {["f"], "a structured muxer"}
        :demuxer -> {["f"], "a structured demuxer"}
        :callbacks -> {@mapping_controls, "output option callbacks"}
        :configured_mappings -> {["i" | @graph_controls], "configured mappings"}
      end

    configured =
      Enum.flat_map(components, fn
        %{options: options} -> Enum.map(options, fn {key, _value} -> to_string(key) end)
        unconfigured when unconfigured in [nil, :copy] -> []
      end)

    reserved = Enum.map(controls ++ configured, &canonical_name/1)

    Enum.each(options, fn {key, _value} ->
      [name | _specifier] = String.split(to_string(key), ":", parts: 2)

      if canonical_name(name) in reserved do
        raise ArgumentError,
              "raw option #{inspect(to_string(key))} cannot be combined with #{owner}"
      end
    end)
  end

  defp canonical_name(name) when name in ["ab", "vb"], do: "b"
  defp canonical_name(name), do: name

  defp validate_av_option!(name, value, callbacks?) do
    if name == "" or String.starts_with?(name, "-") or
         String.contains?(name, [":", " ", "\t", "\n", "\r", <<0>>]) do
      raise ArgumentError,
            "component option names must be unscoped names without leading dashes, got: #{inspect(name)}"
    end

    if name in (@codec_controls ++ @mapping_controls ++ ["f"]) do
      raise ArgumentError, "#{inspect(name)} is a CLI control, not a component AVOption"
    end

    if is_binary(value) and String.contains?(value, <<0>>) do
      raise ArgumentError, "component option values cannot contain NUL"
    end

    cond do
      is_function(value) ->
        validate_callback!(name, value, callbacks?)

      is_binary(value) or is_number(value) or (is_atom(value) and not is_nil(value)) ->
        :ok

      true ->
        raise ArgumentError,
              "component option values must be strings, atoms, numbers, or booleans; use strings for compound values, got: #{inspect(value)}"
    end
  end

  defp validate_callback!(name, callback, allowed?) do
    unless allowed? do
      raise ArgumentError, "option callbacks are only supported on outputs: #{inspect(name)}"
    end

    unless is_function(callback, 1) do
      raise ArgumentError, "option callback #{inspect(name)} must accept one streams argument"
    end
  end

  defp validate_cli_value!(value) when is_binary(value) do
    if String.contains?(value, <<0>>) do
      raise ArgumentError, "CLI option values cannot contain NUL"
    end
  end

  defp validate_cli_value!(nil) do
    raise ArgumentError, "nil is not a CLI option value; use :flag for a valueless switch"
  end

  defp validate_cli_value!(value) when is_atom(value) or is_number(value), do: :ok

  defp validate_cli_value!(values) when is_list(values) do
    Enum.each(values, fn value ->
      if is_function(value) do
        raise ArgumentError, "callbacks must be complete option values"
      end

      validate_cli_value!(value)
    end)
  end

  defp validate_cli_value!(value) do
    raise ArgumentError, "invalid CLI option value: #{inspect(value)}"
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
