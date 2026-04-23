defmodule FF.Command.Build do
  @moduledoc false

  alias FF.Command
  alias FF.Command.Input
  alias FF.Command.Output
  alias FF.Filter.Builder
  alias FF.Graph
  alias FF.Graph.Export

  @role_keys [:video, :audio]
  @removed_role_keys [:subtitle, :subtitles, :data, :attachment]
  @command_keys [:global, :inputs, :graph, :outputs]

  @spec command(keyword()) :: Command.t()
  def command(options) when is_list(options) do
    validate_command_keys!(options)

    {inputs, input_context} = normalize_inputs!(Keyword.get(options, :inputs, []))
    graph = normalize_graph!(Keyword.get(options, :graph), input_context)

    graph_context = graph_context(graph)

    outputs =
      normalize_outputs!(Keyword.get(options, :outputs, []), graph_context, %{
        inputs: input_context
      })

    Command.new(
      global: Keyword.get(options, :global, []),
      inputs: inputs,
      graph: graph,
      outputs: outputs
    )
  end

  @spec output(Output.target(), keyword()) :: Output.t()
  def output(target, options) when is_list(options) do
    if Keyword.keyword?(options) do
      output_from_options!(target, options)
    else
      raise ArgumentError, "output/2 expects keyword options with :video, :audio, or :sources"
    end
  end

  def output(_target, _source) do
    raise ArgumentError, "output/2 expects keyword options with :video, :audio, or :sources"
  end

  defp validate_command_keys!(options) do
    unknown = Keyword.keys(options) -- @command_keys

    if unknown != [] do
      raise ArgumentError, "unknown command keys: #{inspect(unknown)}"
    end
  end

  defp normalize_inputs!(inputs) when is_list(inputs) do
    if Keyword.keyword?(inputs) do
      normalize_input_bindings!(inputs)
    else
      raise ArgumentError, "command inputs must be a keyword list of input/1 or input/2 values"
    end
  end

  defp normalize_inputs!(_inputs) do
    raise ArgumentError, "command inputs must be a keyword list of input/1 or input/2 values"
  end

  defp normalize_input_bindings!(bindings) do
    names = Keyword.keys(bindings)

    if length(names) != length(Enum.uniq(names)) do
      raise ArgumentError,
            "duplicate command input names: #{inspect(names -- Enum.uniq(names))}"
    end

    entries =
      Enum.map(bindings, fn {name, input} ->
        {name, normalize_input_binding!(name, input)}
      end)

    {Enum.map(entries, &elem(&1, 1)), Map.new(entries)}
  end

  defp normalize_input_binding!(_name, %Input{} = input) do
    %{input | id: input.id || make_ref()}
  end

  defp normalize_input_binding!(_name, source) when is_binary(source) do
    Command.input(source)
  end

  defp normalize_input_binding!(name, other) do
    raise ArgumentError,
          "command input #{inspect(name)} must be built with input/1, input/2, or a string source, got: #{inspect(other)}"
  end

  defp normalize_graph!(nil, _input_context), do: nil

  defp normalize_graph!(%Graph{} = graph, _input_context), do: graph

  defp normalize_graph!(fun, input_context) when is_function(fun, 1) do
    fun.(input_context)
    |> graph_from_callback_result!()
  end

  defp normalize_graph!(other, _input_context) do
    raise ArgumentError,
          "command graph must be a %FF.Graph{} or one-arity callback, got: #{inspect(other)}"
  end

  defp graph_from_callback_result!(nil), do: nil

  defp graph_from_callback_result!(%Graph{} = graph), do: graph

  defp graph_from_callback_result!([]), do: nil

  defp graph_from_callback_result!(exports) when is_list(exports) do
    Builder.graph(outputs: exports)
  end

  defp graph_from_callback_result!(other) do
    raise ArgumentError,
          "graph callback must return a %FF.Graph{}, keyword exports, or nil, got: #{inspect(other)}"
  end

  defp graph_context(nil), do: %{}

  defp graph_context(%Graph{} = graph) do
    graph.exports
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {%Export{} = export, index}, context ->
      context
      |> Map.put(index, export)
      |> put_export_name(export)
    end)
  end

  defp put_export_name(context, %Export{name: nil}), do: context
  defp put_export_name(context, %Export{name: name} = export), do: Map.put(context, name, export)

  defp normalize_outputs!(nil, _graph_context, _context), do: []

  defp normalize_outputs!(fun, graph_context, _context) when is_function(fun, 1) do
    fun.(graph_context)
    |> normalize_output_result!()
  end

  defp normalize_outputs!(fun, graph_context, context) when is_function(fun, 2) do
    fun.(graph_context, context)
    |> normalize_output_result!()
  end

  defp normalize_outputs!(%Output{} = output, _graph_context, _context), do: [output]

  defp normalize_outputs!(outputs, _graph_context, _context) when is_list(outputs) do
    normalize_output_result!(outputs)
  end

  defp normalize_outputs!(other, _graph_context, _context) do
    raise ArgumentError, "command outputs must be a list or callback, got: #{inspect(other)}"
  end

  defp normalize_output_result!(%Output{} = output), do: [output]

  defp normalize_output_result!(outputs) when is_list(outputs) do
    Enum.each(outputs, fn
      %Output{} -> :ok
      other -> raise ArgumentError, "invalid command output: #{inspect(other)}"
    end)

    outputs
  end

  defp normalize_output_result!(other) do
    raise ArgumentError,
          "outputs callback must return an output or list of outputs, got: #{inspect(other)}"
  end

  defp output_from_options!(target, options) do
    removed_roles = Keyword.keys(options) |> Enum.filter(&(&1 in @removed_role_keys))

    if removed_roles != [] do
      raise ArgumentError,
            "unsupported output media roles: #{inspect(removed_roles)}; use :video, :audio, or :sources"
    end

    role_options = Keyword.take(options, @role_keys)
    sources = Keyword.get(options, :sources)

    if sources != nil and role_options != [] do
      raise ArgumentError, "output/2 accepts either media roles or :sources, not both"
    end

    sources =
      cond do
        sources != nil ->
          sources

        role_options != [] ->
          @role_keys
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

    command_options = Keyword.drop(options, @role_keys ++ [:sources])
    Command.output(target, sources, command_options)
  end
end
