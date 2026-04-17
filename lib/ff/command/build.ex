defmodule FF.Command.Build do
  @moduledoc false

  alias FF.Command
  alias FF.Command.Input
  alias FF.Command.Output
  alias FF.Filter.Builder
  alias FF.Graph
  alias FF.Graph.Export
  alias FF.Graph.InputRef

  @role_keys [:video, :audio, :subtitle, :subtitles, :data, :attachment]
  @command_keys [:global, :inputs, :graph, :outputs]
  @graph_keys [:output, :outputs, :terminals, :settings]

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

  @spec output(Output.target(), keyword() | Command.source() | [Command.source()]) :: Output.t()
  def output(target, options_or_sources) when is_list(options_or_sources) do
    if Keyword.keyword?(options_or_sources) do
      output_from_options!(target, options_or_sources)
    else
      Command.output(target, options_or_sources)
    end
  end

  def output(target, source), do: Command.output(target, source)

  defp validate_command_keys!(options) do
    unknown = Keyword.keys(options) -- @command_keys

    if unknown != [] do
      raise ArgumentError, "unknown command keys: #{inspect(unknown)}"
    end
  end

  defp normalize_inputs!(inputs) when is_list(inputs) do
    cond do
      inputs == [] ->
        {[], %{}}

      Keyword.keyword?(inputs) ->
        normalize_input_bindings!(inputs)

      true ->
        normalize_input_list!(inputs)
    end
  end

  defp normalize_inputs!(_inputs) do
    raise ArgumentError, "command inputs must be a list"
  end

  defp normalize_input_bindings!(bindings) do
    labels = Keyword.keys(bindings)

    if length(labels) != length(Enum.uniq(labels)) do
      raise ArgumentError,
            "duplicate command input labels: #{inspect(labels -- Enum.uniq(labels))}"
    end

    entries =
      Enum.map(bindings, fn {label, spec} ->
        {label, normalize_input_binding!(label, spec)}
      end)

    {Enum.map(entries, &elem(&1, 1)), Map.new(entries)}
  end

  defp normalize_input_binding!(label, %Input{} = input) do
    put_input_label!(input, label)
  end

  defp normalize_input_binding!(label, {source, options}) when is_list(options) do
    source
    |> Command.input(options)
    |> put_input_label!(label)
  end

  defp normalize_input_binding!(label, source) do
    source
    |> Command.input()
    |> put_input_label!(label)
  end

  defp normalize_input_list!(inputs) do
    Enum.each(inputs, fn
      %Input{} -> :ok
      other -> raise ArgumentError, "invalid command input: #{inspect(other)}"
    end)

    {inputs, input_context_from_list(inputs)}
  end

  defp input_context_from_list(inputs) do
    Enum.reduce(inputs, %{}, fn
      %Input{label: nil}, context ->
        context

      %Input{label: label} = input, context ->
        context
        |> Map.put(label, input)
        |> maybe_put_existing_atom(label, input)
    end)
  end

  defp maybe_put_existing_atom(context, label, input) when is_binary(label) do
    atom_label = String.to_existing_atom(label)
    Map.put(context, atom_label, input)
  rescue
    ArgumentError -> context
  end

  defp put_input_label!(%Input{} = input, label) do
    normalized_label = normalize_input_label!(label)

    case input.label do
      nil ->
        %{input | id: input.id || make_ref(), label: normalized_label}

      ^normalized_label ->
        %{input | id: input.id || make_ref()}

      other ->
        raise ArgumentError,
              "input label #{inspect(other)} does not match declared input name #{inspect(normalized_label)}"
    end
  end

  defp normalize_input_label!(label) do
    case InputRef.normalize_input_id!(label) do
      label when is_binary(label) -> label
      _label -> raise ArgumentError, "input label must be an atom or non-empty string"
    end
  end

  defp normalize_graph!(nil, _input_context), do: nil

  defp normalize_graph!(%Graph{} = graph, _input_context), do: graph

  defp normalize_graph!(fun, input_context) when is_function(fun, 1) do
    fun.(input_context)
    |> graph_from_callback_result!()
  end

  defp normalize_graph!(graph_spec, _input_context) when is_list(graph_spec) do
    graph_from_callback_result!(graph_spec)
  end

  defp normalize_graph!(other, _input_context) do
    raise ArgumentError, "invalid command graph: #{inspect(other)}"
  end

  defp graph_from_callback_result!(nil), do: nil

  defp graph_from_callback_result!(%Graph{} = graph), do: graph

  defp graph_from_callback_result!([]), do: nil

  defp graph_from_callback_result!(graph_options) when is_list(graph_options) do
    if graph_options?(graph_options) do
      Builder.graph(graph_options)
    else
      Builder.graph(outputs: graph_options)
    end
  end

  defp graph_from_callback_result!(other) do
    raise ArgumentError,
          "graph callback must return a graph, keyword outputs, graph options, or nil, got: #{inspect(other)}"
  end

  defp graph_options?(options) do
    Keyword.keyword?(options) and Enum.any?(Keyword.keys(options), &(&1 in @graph_keys))
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
