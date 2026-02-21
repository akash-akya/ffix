defmodule FF.DSL do
  @moduledoc false

  @role_keys [:video, :audio, :subtitle, :data, :attachment]

  defmacro command(options_ast) do
    unless keyword_literal?(options_ast) do
      raise ArgumentError,
            "DSL command expects a literal keyword list; use FF.command/1 for dynamic command assembly"
    end

    {input_bindings, inputs_ast} = build_inputs(Keyword.get(options_ast, :inputs, []))
    graph_ast = build_graph(Keyword.get(options_ast, :graph, nil))
    outputs_ast = build_outputs(Keyword.get(options_ast, :outputs, []))

    option_pairs =
      options_ast
      |> Keyword.drop([:inputs, :graph, :outputs])
      |> Enum.map(fn {key, value} -> quote(do: {unquote(key), unquote(value)}) end)

    option_pairs =
      option_pairs ++
        [
          quote(do: {:inputs, unquote(inputs_ast)}),
          quote(do: {:graph, unquote(graph_ast)}),
          quote(do: {:outputs, unquote(outputs_ast)})
        ]

    quote do
      unquote_splicing(input_bindings)
      FF.command([unquote_splicing(option_pairs)])
    end
  end

  @doc false
  def __input__(source), do: FF.Command.input(source)
  def __input__(source, options), do: FF.Command.input(source, options)

  @doc false
  def __label_input__(input, label) do
    normalized_label = normalize_dsl_label!(label)

    case input do
      %FF.Command.Input{label: nil} = input ->
        %{input | id: input.id || make_ref(), label: normalized_label}

      %FF.Command.Input{label: ^normalized_label} = input ->
        %{input | id: input.id || make_ref()}

      %FF.Command.Input{label: other} ->
        raise ArgumentError,
              "input label #{inspect(other)} does not match declared input name #{inspect(normalized_label)}"

      other ->
        raise ArgumentError, "DSL input must produce %FF.Command.Input{}, got: #{inspect(other)}"
    end
  end

  @doc false
  def __output__(target, options) when is_list(options) do
    role_keys = role_keys()
    role_options = Keyword.take(options, role_keys)
    sources = Keyword.get(options, :sources)

    if sources && role_options != [] do
      raise ArgumentError, "output/2 accepts either media roles or :sources, not both"
    end

    sources =
      cond do
        sources != nil ->
          sources

        role_options != [] ->
          role_keys
          |> Enum.flat_map(fn key ->
            case Keyword.get(role_options, key) do
              nil -> []
              values when is_list(values) -> values
              value -> [value]
            end
          end)

        true ->
          raise ArgumentError, "output/2 expects at least one media role or :sources"
      end

    command_options = Keyword.drop(options, role_keys ++ [:sources])
    FF.Command.output(target, sources, command_options)
  end

  def __output__(target, options) do
    raise ArgumentError,
          "output options must be a keyword list, got: #{inspect({target, options})}"
  end

  defp role_keys, do: @role_keys

  defp normalize_dsl_label!(label) do
    case FF.Graph.InputRef.normalize_input_id!(label) do
      label when is_binary(label) -> label
      _label -> raise ArgumentError, "DSL input name must be an atom or non-empty string"
    end
  end

  defp build_inputs(inputs_ast) do
    unless keyword_literal?(inputs_ast) do
      raise ArgumentError,
            "DSL command inputs expect a literal keyword list of named inputs"
    end

    inputs =
      Enum.map(inputs_ast, fn {label, input_ast} ->
        unless is_atom(label) do
          raise ArgumentError, "DSL input names must be atoms, got: #{inspect(label)}"
        end

        var = Macro.var(label, nil)

        binding =
          quote do
            unquote(var) = unquote(labeled_input_ast(input_ast, label))
          end

        {binding, var}
      end)

    bindings = Enum.map(inputs, &elem(&1, 0))
    vars = Enum.map(inputs, &elem(&1, 1))

    {bindings, quote(do: [unquote_splicing(vars)])}
  end

  defp build_graph(nil), do: nil

  defp build_graph(graph_ast) do
    if keyword_literal?(graph_ast) do
      quote do
        FF.graph(outputs: unquote(graph_ast))
      end
    else
      graph_ast
    end
  end

  defp build_outputs(outputs_ast) do
    unless is_list(outputs_ast) do
      raise ArgumentError, "DSL command outputs expect a list"
    end

    outputs_ast
    |> Enum.map(&transform_output_ast/1)
    |> then(&quote(do: [unquote_splicing(&1)]))
  end

  defp transform_output_ast({:output, _meta, [target, options]}) do
    quote do
      FF.DSL.__output__(unquote(target), unquote(options))
    end
  end

  defp transform_output_ast(other), do: other

  defp labeled_input_ast({:input, _meta, args}, label) do
    quote do
      FF.DSL.__label_input__(FF.DSL.__input__(unquote_splicing(args)), unquote(label))
    end
  end

  defp labeled_input_ast(
         {{:., _, [{:__aliases__, _, [:FF, :Command]}, :input]}, _meta, args},
         label
       ) do
    quote do
      FF.DSL.__label_input__(FF.Command.input(unquote_splicing(args)), unquote(label))
    end
  end

  defp labeled_input_ast(other, label) do
    quote do
      FF.DSL.__label_input__(unquote(other), unquote(label))
    end
  end

  defp keyword_literal?(value) when is_list(value) do
    Enum.all?(value, fn
      {key, _value} when is_atom(key) -> true
      _other -> false
    end)
  end

  defp keyword_literal?(_value), do: false
end
