defmodule FFix.Command.Build do
  @moduledoc false

  alias FFix.Command
  alias FFix.Command.Input
  alias FFix.Command.Mapping
  alias FFix.Command.Output
  alias FFix.Graph.Merge
  alias FFix.Graph.Terminal
  alias FFix.Graph.Export
  alias FFix.Graph.StreamRef
  alias FFix.Selection

  @command_keys [:global, :inputs, :terminals, :settings]

  @spec command(Output.t() | [Output.t()], keyword()) :: Command.t()
  def command(output_or_outputs, options \\ []) do
    validate_options!(options)
    outputs = normalize_outputs!(output_or_outputs)
    sources = mapped_sources!(outputs)
    terminals = Keyword.get(options, :terminals, [])

    unless is_list(terminals) do
      raise ArgumentError, "command terminals must be an ordered list"
    end

    Enum.each(terminals, &Terminal.validate!/1)
    initial = {Merge.new(Keyword.get(options, :settings, [])), []}

    {graph, reversed_inputs} =
      Enum.reduce(sources ++ terminals, initial, fn
        %Selection{input_ref: input_ref}, {graph, inputs} ->
          {graph, [input_ref | inputs]}

        source, {graph, inputs} ->
          {graph, added_inputs} = Merge.add(graph, source.graph)
          {graph, Enum.reverse(added_inputs, inputs)}
      end)

    input_refs = Enum.reverse(reversed_inputs)

    captured_inputs =
      input_refs
      |> Enum.map(& &1.declaration)
      |> Enum.reject(&is_nil/1)
      |> unique_inputs!()

    inputs = resolve_inputs!(captured_inputs, input_refs, options)

    filters? = Enum.any?(graph.nodes, fn {_id, node} -> node.kind == :filter end)

    if not filters? and graph.settings != [] do
      raise ArgumentError,
            "graph settings require filter nodes; cannot discard settings from a direct mapping command"
    end

    exports =
      sources
      |> Enum.filter(&is_struct(&1, StreamRef))
      |> Enum.map(fn stream ->
        %Export{graph_id: graph.id, ref: stream.ref, media: stream.media}
      end)

    outputs = lower_outputs(outputs, exports)

    graph =
      if map_size(graph.nodes) == 0 do
        nil
      else
        %{graph | exports: exports}
      end

    Command.new(
      global: Keyword.get(options, :global, []),
      inputs: inputs,
      graph: graph,
      outputs: outputs
    )
    |> Command.validate!()
  end

  defp validate_options!(options) do
    unless Keyword.keyword?(options) do
      raise ArgumentError, "command options must be a keyword list"
    end

    keys = Keyword.keys(options)

    if length(keys) != length(Enum.uniq(keys)) do
      raise ArgumentError, "duplicate command option"
    end

    unknown = keys -- @command_keys

    if unknown != [] do
      raise ArgumentError,
            "unknown command keys: #{inspect(unknown)}; pass output declarations as the first argument"
    end
  end

  defp normalize_outputs!(output_or_outputs) do
    outputs = List.wrap(output_or_outputs)

    if outputs == [] do
      raise ArgumentError, "command requires at least one output"
    end

    Enum.each(outputs, fn
      %Output{mappings: mappings} when is_list(mappings) -> :ok
      other -> raise ArgumentError, "expected an Output declaration, got: #{inspect(other)}"
    end)

    outputs
  end

  defp mapped_sources!(outputs) do
    Enum.flat_map(outputs, fn output ->
      Enum.map(output.mappings, fn
        %Mapping{source: %StreamRef{} = stream} ->
          StreamRef.node!(stream)
          stream

        %Mapping{source: %Selection{} = selection} ->
          Selection.validate!(selection)

        %Mapping{source: %Export{}} ->
          raise ArgumentError,
                "bare graph Export sources are not supported by output-first commands; use graph[:name] for a captured stream, or Command.new/1 with an explicit graph"

        other ->
          raise ArgumentError,
                "expected a mapping with a stream reference or selection, got: #{inspect(other)}"
      end)
    end)
  end

  defp resolve_inputs!(captured_inputs, input_refs, options) do
    case Keyword.fetch(options, :inputs) do
      :error ->
        if Enum.any?(input_refs, &is_nil(&1.declaration)) do
          raise ArgumentError,
                "unbound input reference; select streams from Input.new/2 declarations, bind graph inputs, or supply an explicit ordered :inputs list"
        end

        captured_inputs

      {:ok, explicit_inputs} ->
        inputs = unique_inputs!(explicit_inputs)
        declarations = Map.new(inputs, &{&1.id, &1})

        Enum.each(captured_inputs, fn captured ->
          case Map.fetch(declarations, captured.id) do
            {:ok, ^captured} ->
              :ok

            {:ok, _conflicting} ->
              raise ArgumentError,
                    "conflicting input snapshots for declaration #{inspect(captured.id)}"

            :error ->
              raise ArgumentError,
                    "captured input declaration #{inspect(captured.id)} is missing from explicit :inputs"
          end
        end)

        inputs
    end
  end

  defp unique_inputs!(inputs) do
    unless is_list(inputs) do
      raise ArgumentError, "command inputs must be an explicit ordered list of Input declarations"
    end

    {reversed, _seen} =
      Enum.reduce(inputs, {[], %{}}, fn input, {ordered, seen} ->
        unless is_struct(input, Input) do
          raise ArgumentError, "expected an Input declaration, got: #{inspect(input)}"
        end

        Command.validate_input!(input)

        case Map.fetch(seen, input.id) do
          {:ok, ^input} when input.id != nil ->
            {ordered, seen}

          {:ok, _conflicting} when input.id != nil ->
            raise ArgumentError,
                  "conflicting input snapshots for declaration #{inspect(input.id)}"

          _new ->
            {[input | ordered], Map.put(seen, input.id, input)}
        end
      end)

    Enum.reverse(reversed)
  end

  defp lower_outputs(outputs, exports) do
    {outputs, _remaining} =
      Enum.map_reduce(outputs, exports, fn output, remaining ->
        {mappings, remaining} =
          Enum.map_reduce(output.mappings, remaining, fn
            %{source: %Selection{}} = mapping, remaining -> {mapping, remaining}
            mapping, [export | rest] -> {%{mapping | source: export}, rest}
          end)

        {%{output | mappings: mappings}, remaining}
      end)

    outputs
  end
end
