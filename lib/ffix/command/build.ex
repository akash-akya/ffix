defmodule FFix.Command.Build do
  @moduledoc false

  alias FFix.Command
  alias FFix.Command.Input
  alias FFix.Command.Mapping
  alias FFix.Command.Output
  alias FFix.Filter.Builder
  alias FFix.Graph
  alias FFix.Stream

  @role_keys [:video, :audio]
  @removed_role_keys [:subtitle, :subtitles, :data, :attachment]
  @command_keys [:global, :inputs, :graph, :outputs]
  @callback_command_keys [:global]

  @spec command(keyword()) :: Command.t()
  def command(options) when is_list(options) do
    validate_command_keys!(options)

    build_command(
      Keyword.get(options, :global, []),
      Keyword.get(options, :inputs, []),
      Keyword.get(options, :graph),
      Keyword.get(options, :outputs, [])
    )
  end

  @spec command(term(), (term() -> Output.t() | [Output.t()])) :: Command.t()
  def command(inputs, outputs_fun), do: command(inputs, outputs_fun, [])

  @spec command(term(), function(), function() | keyword()) :: Command.t()
  def command(inputs, outputs_fun, options)
      when is_function(outputs_fun, 1) and is_list(options) do
    validate_callback_command_options!(options)
    {command_inputs, input_value} = normalize_input_shape!(inputs)
    outputs = normalize_output_result!(outputs_fun.(input_value))
    {graph, outputs} = export_output_sources(outputs)

    Command.new(
      global: Keyword.get(options, :global, []),
      inputs: command_inputs,
      graph: graph,
      outputs: outputs
    )
  end

  def command(inputs, graph_fun, outputs_fun)
      when is_function(graph_fun, 1) and is_function(outputs_fun) do
    build_command([], inputs, graph_fun, outputs_fun)
  end

  @spec command(
          Input.source() | Input.t() | [Input.source() | Input.t()] | keyword() | map(),
          function(),
          function(),
          keyword()
        ) :: Command.t()
  def command(inputs, graph_fun, outputs_fun, options)
      when is_function(graph_fun, 1) and is_function(outputs_fun) and is_list(options) do
    validate_callback_command_options!(options)
    build_command(Keyword.get(options, :global, []), inputs, graph_fun, outputs_fun)
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

  defp validate_callback_command_options!(options) do
    unless Keyword.keyword?(options) do
      raise ArgumentError, "command options must be a keyword list"
    end

    unknown = Keyword.keys(options) -- @callback_command_keys

    if unknown != [] do
      raise ArgumentError,
            "command/4 options only support :global; pass inputs, graph, and outputs as positional arguments, got: #{inspect(unknown)}"
    end
  end

  defp build_command(global, inputs, graph, outputs) do
    {command_inputs, input_value} = normalize_input_shape!(inputs)
    {command_graph, graph_value} = normalize_graph!(graph, input_value)
    command_outputs = normalize_outputs!(outputs, graph_value, input_value)

    Command.new(
      global: global,
      inputs: command_inputs,
      graph: command_graph,
      outputs: command_outputs
    )
  end

  defp export_output_sources(outputs) do
    streams =
      outputs
      |> Enum.flat_map(& &1.mappings)
      |> Enum.flat_map(fn mapping ->
        case mapping do
          %Mapping{source: %Stream{plan: %{kind: :filter}} = source} -> [source]
          %Mapping{} -> []
          other -> raise ArgumentError, "invalid output mapping: #{inspect(other)}"
        end
      end)
      |> Enum.uniq_by(&stream_key/1)

    case streams do
      [] ->
        {nil, outputs}

      streams ->
        graph = Builder.graph(outputs: streams)
        exports = Enum.zip(streams, Graph.exports(graph))
        exports = Map.new(exports, fn {stream, export} -> {stream_key(stream), export} end)

        outputs =
          Enum.map(outputs, fn output ->
            mappings = Enum.map(output.mappings, &export_mapping(&1, exports))
            %{output | mappings: mappings}
          end)

        {graph, outputs}
    end
  end

  defp export_mapping(mapping, exports) do
    case mapping.source do
      %Stream{plan: %{kind: :filter}} = source ->
        %{mapping | source: Map.fetch!(exports, stream_key(source))}

      _source ->
        mapping
    end
  end

  defp stream_key(%Stream{plan: plan, output: output}), do: {plan.id, output}

  defp normalize_input_shape!(%Input{} = input) do
    input = normalize_input_value!(:input, input)
    {[input], input}
  end

  defp normalize_input_shape!(source) when is_binary(source) or source == :stdin do
    input = normalize_input_value!(:input, source)
    {[input], input}
  end

  defp normalize_input_shape!({:pipe, fd} = source) when is_integer(fd) and fd >= 0 do
    input = normalize_input_value!(:input, source)
    {[input], input}
  end

  defp normalize_input_shape!({:url, url} = source) when is_binary(url) do
    input = normalize_input_value!(:input, source)
    {[input], input}
  end

  defp normalize_input_shape!(inputs) when is_list(inputs) do
    if Keyword.keyword?(inputs) do
      normalize_input_keyword_shape!(inputs)
    else
      input_values = Enum.map(inputs, &normalize_input_value!(:input, &1))
      {input_values, input_values}
    end
  end

  defp normalize_input_shape!(inputs) when is_map(inputs) do
    entries =
      Enum.map(inputs, fn {key, input} ->
        {key, normalize_input_value!(key, input)}
      end)

    {Enum.map(entries, &elem(&1, 1)), Map.new(entries)}
  end

  defp normalize_input_shape!(other) do
    raise ArgumentError,
          "command inputs must be a source, input, list, keyword list, or map, got: #{inspect(other)}"
  end

  defp normalize_input_keyword_shape!(bindings) do
    names = Keyword.keys(bindings)

    if length(names) != length(Enum.uniq(names)) do
      raise ArgumentError,
            "duplicate command input names: #{inspect(names -- Enum.uniq(names))}"
    end

    entries =
      Enum.map(bindings, fn {name, input} ->
        {name, normalize_input_value!(name, input)}
      end)

    {Enum.map(entries, &elem(&1, 1)), entries}
  end

  defp normalize_input_value!(_name, %Input{} = input), do: %{input | id: input.id || make_ref()}
  defp normalize_input_value!(_name, source) when is_binary(source), do: Command.input(source)
  defp normalize_input_value!(_name, :stdin), do: Command.input(:stdin)

  defp normalize_input_value!(_name, {:pipe, fd}) when is_integer(fd) and fd >= 0,
    do: Command.input({:pipe, fd})

  defp normalize_input_value!(_name, {:url, url}) when is_binary(url),
    do: Command.input({:url, url})

  defp normalize_input_value!(name, other) do
    raise ArgumentError,
          "command input #{inspect(name)} must be built with input/1, input/2, or a source, got: #{inspect(other)}"
  end

  defp normalize_graph!(nil, _input_context), do: {nil, nil}

  defp normalize_graph!(%Graph{} = graph, _input_context), do: {graph, graph}

  defp normalize_graph!(fun, input_context) when is_function(fun, 1) do
    graph_result = fun.(input_context)
    graph = graph_from_callback_result!(graph_result)
    {graph, graph_callback_value!(graph_result, graph)}
  end

  defp normalize_graph!(other, _input_context) do
    raise ArgumentError,
          "command graph must be a %FFix.Graph{} or one-arity callback, got: #{inspect(other)}"
  end

  defp graph_from_callback_result!(nil), do: nil

  defp graph_from_callback_result!(%Graph{} = graph), do: graph

  defp graph_from_callback_result!(%Stream{} = stream), do: Builder.graph(output: stream)

  defp graph_from_callback_result!([]), do: nil

  defp graph_from_callback_result!(values) when is_list(values) do
    values
    |> graph_outputs_from_list!()
    |> graph_from_outputs!()
  end

  defp graph_from_callback_result!(values) when is_map(values) do
    values
    |> Map.to_list()
    |> graph_outputs_from_map_entries!()
    |> graph_from_outputs!()
  end

  defp graph_from_callback_result!(other) do
    raise ArgumentError,
          "graph callback must return a %FFix.Graph{}, stream, list, keyword list, map, or nil, got: #{inspect(other)}"
  end

  defp graph_callback_value!(nil, nil), do: nil
  defp graph_callback_value!(%Graph{} = graph, %Graph{}), do: graph
  defp graph_callback_value!(%Stream{}, %Graph{} = graph), do: Graph.export!(graph, 0)
  defp graph_callback_value!([], nil), do: []

  defp graph_callback_value!(values, %Graph{} = graph) when is_list(values) do
    exports = Graph.exports(graph)

    if Keyword.keyword?(values) do
      values
      |> Enum.zip(exports)
      |> Enum.map(fn {{key, _value}, export} -> {key, export} end)
    else
      exports
    end
  end

  defp graph_callback_value!(values, nil) when is_list(values), do: values

  defp graph_callback_value!(values, %Graph{} = graph) when is_map(values) do
    values
    |> Map.keys()
    |> Enum.zip(Graph.exports(graph))
    |> Map.new()
  end

  defp graph_callback_value!(values, nil) when is_map(values), do: values

  defp graph_outputs_from_list!(values) do
    if Keyword.keyword?(values) do
      Enum.map(values, fn {name, value} -> {name, normalize_graph_output!(name, value)} end)
    else
      Enum.map(values, &normalize_graph_output!(:output, &1))
    end
  end

  defp graph_outputs_from_map_entries!(entries) do
    Enum.map(entries, fn
      {name, value} when is_atom(name) ->
        {name, normalize_graph_output!(name, value)}

      {_name, value} ->
        normalize_graph_output!(:output, value)
    end)
  end

  defp normalize_graph_output!(_name, %Stream{} = stream), do: stream

  defp normalize_graph_output!(name, other) do
    raise ArgumentError,
          "graph output #{inspect(name)} must be an FFix.Stream, got: #{inspect(other)}"
  end

  defp graph_from_outputs!([]), do: nil
  defp graph_from_outputs!(outputs), do: Builder.graph(outputs: outputs)

  defp normalize_outputs!(nil, _graph_value, _input_context), do: []

  defp normalize_outputs!(fun, graph_value, _input_context) when is_function(fun, 1) do
    fun.(graph_value)
    |> normalize_output_result!()
  end

  defp normalize_outputs!(fun, graph_value, input_context) when is_function(fun, 2) do
    fun.(graph_value, input_context)
    |> normalize_output_result!()
  end

  defp normalize_outputs!(%Output{} = output, _graph_value, _input_context), do: [output]

  defp normalize_outputs!(outputs, _graph_value, _input_context) when is_list(outputs) do
    normalize_output_result!(outputs)
  end

  defp normalize_outputs!(other, _graph_value, _input_context) do
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
