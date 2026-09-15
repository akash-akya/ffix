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
    validate_pairs!(options)
    {special, remaining} = Enum.split_with(options, fn {key, _value} -> key in keys end)
    special_names = Enum.map(special, fn {key, _value} -> key end)

    validate_unique_names!(
      special_names,
      "duplicate option; specify each of #{inspect(keys)} at most once"
    )

    {special, remaining}
  end

  def normalize!(options, schema, context) do
    {bindings, checked_options} = split!(options, [:raw])
    raw_options = Keyword.get(bindings, :raw, [])
    validate_pairs!(raw_options)

    checked_options = stringify_names(checked_options)
    raw_options = stringify_names(raw_options)

    normalized_options =
      case schema do
        nil -> checked_options
        schema -> Enum.map(checked_options, &normalize_option!(&1, schema, context))
      end

    combined_options = normalized_options ++ raw_options
    names = Enum.map(combined_options, fn {name, _value} -> name end)
    validate_unique_names!(names, "duplicate option in #{context}; specify each option once")
    combined_options
  end

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
        value when is_binary(value) -> nonempty_argument?(value)
        {:url, value} -> nonempty_argument?(value)
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
    validate_pairs!(options)

    Enum.each(options, fn {key, value} ->
      name = to_string(key)

      unless valid_option_name?(name) do
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
    unless component.name == nil or nonempty_argument?(component.name) do
      raise ArgumentError, "component name must be a non-empty string or nil"
    end

    if match?(%Encoder{name: "copy"}, component) do
      raise ArgumentError, "copy is a mapping mode; use encoding: :copy"
    end

    validate_pairs!(component.options)
    callbacks? = is_struct(component, Encoder) or is_struct(component, Muxer)

    names =
      Enum.map(component.options, fn {key, value} ->
        name = to_string(key)
        validate_av_option!(name, value, callbacks?)
        name
      end)

    validate_unique_names!(names, "duplicate component option; specify each option once")
    component
  end

  def callbacks?(configuration) do
    case configuration do
      %{options: options} -> callbacks?(options)
      unconfigured when unconfigured in [nil, :copy] -> false
      options -> Enum.any?(options, fn {_name, value} -> is_function(value) end)
    end
  end

  def reject_conflicts!(options, role, components \\ []) do
    {controls, owner} = conflict_rules(role)

    configured_options =
      Enum.flat_map(components, fn
        %{options: options} -> options
        unconfigured when unconfigured in [nil, :copy] -> []
      end)

    configured_names = Enum.map(configured_options, fn {key, _value} -> to_string(key) end)
    reserved_names = Enum.map(controls ++ configured_names, &canonical_name/1)

    Enum.each(options, fn {key, _value} ->
      name = to_string(key)
      [base_name | _specifier] = String.split(name, ":", parts: 2)

      if canonical_name(base_name) in reserved_names do
        raise ArgumentError, "raw option #{inspect(name)} cannot be combined with #{owner}"
      end
    end)
  end

  defp validate_pairs!(options) do
    unless is_list(options) do
      raise ArgumentError, "options must be a list of name/value pairs"
    end

    Enum.each(options, fn
      {key, _value} when is_atom(key) or is_binary(key) -> :ok
      other -> raise ArgumentError, "invalid option: #{inspect(other)}"
    end)
  end

  defp validate_unique_names!(names, message) do
    if names != Enum.uniq(names) do
      raise ArgumentError, message
    end
  end

  defp stringify_names(options) do
    Enum.map(options, fn {key, value} -> {to_string(key), value} end)
  end

  defp nonempty_argument?(value) do
    is_binary(value) and value != "" and not String.contains?(value, <<0>>)
  end

  defp valid_option_name?(name) do
    name != "" and not String.starts_with?(name, "-") and
      not String.contains?(name, [" ", "\t", "\n", "\r", <<0>>])
  end

  defp scalar?(value) do
    is_binary(value) or is_number(value) or (is_atom(value) and not is_nil(value))
  end

  defp validate_av_option!(name, value, callbacks?) do
    unless valid_option_name?(name) and not String.contains?(name, ":") do
      raise ArgumentError,
            "component option names must be unscoped names without leading dashes, got: #{inspect(name)}"
    end

    if name in (@codec_controls ++ @mapping_controls ++ ["f"]) do
      raise ArgumentError, "#{inspect(name)} is a CLI control, not a component AVOption"
    end

    cond do
      is_binary(value) and String.contains?(value, <<0>>) ->
        raise ArgumentError, "component option values cannot contain NUL"

      is_function(value) ->
        validate_callback!(name, value, callbacks?)

      scalar?(value) ->
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

  defp validate_cli_value!(value) do
    case value do
      value when is_binary(value) ->
        if String.contains?(value, <<0>>) do
          raise ArgumentError, "CLI option values cannot contain NUL"
        end

      nil ->
        raise ArgumentError, "nil is not a CLI option value; use :flag for a valueless switch"

      value when is_atom(value) or is_number(value) ->
        :ok

      values when is_list(values) ->
        Enum.each(values, &validate_cli_value!/1)

      callback when is_function(callback) ->
        raise ArgumentError, "callbacks must be complete option values"

      other ->
        raise ArgumentError, "invalid CLI option value: #{inspect(other)}"
    end
  end

  defp conflict_rules(role) do
    case role do
      :encoding -> {@codec_controls ++ @mapping_controls, "structured encoding"}
      :decoding -> {@codec_controls, "structured decoding"}
      :muxer -> {["f"], "a structured muxer"}
      :demuxer -> {["f"], "a structured demuxer"}
      :callbacks -> {@mapping_controls, "output option callbacks"}
      :configured_mappings -> {["i" | @graph_controls], "configured mappings"}
    end
  end

  defp canonical_name(name) do
    case name do
      name when name in ["ab", "vb"] -> "b"
      name -> name
    end
  end

  defp normalize_option!({name, value}, schema, context) do
    variants = option_spec!(schema, name, context)

    normalized_value =
      if is_function(value, 1) do
        fn streams ->
          callback_value = value.(streams)
          normalize_value!(callback_value, variants, name, context)
        end
      else
        normalize_value!(value, variants, name, context)
      end

    {name, normalized_value}
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
      |> Enum.map(fn candidate -> {candidate, String.jaro_distance(name, candidate)} end)
      |> Enum.max_by(fn {_candidate, score} -> score end, fn -> nil end)

    suggestion =
      case nearest do
        {candidate, score} when score >= 0.8 -> " Did you mean #{inspect(candidate)}?"
        _other -> ""
      end

    "unknown #{context} option #{inspect(name)}." <>
      suggestion <>
      " Use raw: [{name, value}] for options outside the recorded schema."
  end

  defp normalize_value!(value, variants, name, context) do
    unless Enum.any?(variants, &accepts?(&1, value)) do
      raise ArgumentError,
            "invalid value #{inspect(value)} for #{context} option #{inspect(name)}; use an FFmpeg string for expressions or compound values"
    end

    case value do
      [] -> "0"
      values when is_list(values) -> Enum.map_join(values, "+", &to_string/1)
      value when is_atom(value) and not is_boolean(value) -> Atom.to_string(value)
      value -> value
    end
  end

  defp accepts?(%{type: type, constants: constants}, value) do
    cond do
      match?({:unknown, _name}, type) ->
        scalar?(value)

      is_nil(value) ->
        false

      is_binary(value) ->
        true

      is_boolean(value) ->
        type == :boolean

      is_integer(value) ->
        type in @integer_types or type in @number_types

      is_float(value) ->
        type in @number_types

      is_atom(value) ->
        type in @string_types or Atom.to_string(value) in constants or
          (type == :boolean and value == :auto)

      is_list(value) ->
        type == :flags and
          Enum.all?(value, fn flag ->
            is_binary(flag) or (is_atom(flag) and Atom.to_string(flag) in constants)
          end)

      true ->
        false
    end
  end
end
