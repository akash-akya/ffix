defmodule FFix.Command.Build do
  @moduledoc false

  alias FFix.Command
  alias FFix.Command.{Input, Mapping, Output}
  alias FFix.Graph.{Export, Merge, StreamRef, Terminal}
  alias FFix.Selection

  @spec command(Output.t() | [Output.t()], keyword()) :: Command.t()
  def command(output_or_outputs, options \\ []) do
    Command.validate_keys!(options, [:global, :inputs, :terminals, :settings])
    outputs = normalize_outputs!(output_or_outputs)
    initial = {Merge.new(Keyword.get(options, :settings, [])), []}

    {outputs, {graph, reversed_inputs}} =
      Enum.map_reduce(outputs, initial, fn output, state ->
        {mappings, state} = Enum.map_reduce(output.mappings, state, &lower_mapping!/2)
        {%{output | mappings: mappings}, state}
      end)

    terminals = Keyword.get(options, :terminals, [])

    unless is_list(terminals) do
      raise ArgumentError, "command terminals must be an ordered list"
    end

    {graph, reversed_inputs} =
      Enum.reduce(terminals, {graph, reversed_inputs}, fn terminal, {graph, inputs} ->
        Terminal.validate!(terminal)
        {graph, added_inputs} = Merge.add(graph, terminal.graph)
        {graph, Enum.reverse(added_inputs, inputs)}
      end)

    input_refs = Enum.reverse(reversed_inputs)
    inputs = resolve_inputs!(input_refs, options)

    graph =
      if map_size(graph.nodes) == 0 and graph.settings == [] do
        nil
      else
        %{graph | exports: Enum.reverse(graph.exports)}
      end

    command = %Command{
      global_options: Keyword.get(options, :global, []),
      inputs: inputs,
      graph: graph,
      outputs: outputs
    }

    Command.validate!(command)
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

  defp lower_mapping!(%Mapping{source: %StreamRef{} = stream} = mapping, {graph, inputs}) do
    StreamRef.node!(stream)
    {graph, added_inputs} = Merge.add(graph, stream.graph)
    export = %Export{graph_id: graph.id, ref: stream.ref, media: stream.media}
    graph = %{graph | exports: [export | graph.exports]}
    {%{mapping | source: export}, {graph, Enum.reverse(added_inputs, inputs)}}
  end

  defp lower_mapping!(%Mapping{source: %Selection{} = selection} = mapping, {graph, inputs}) do
    Selection.validate!(selection)
    {mapping, {graph, [selection.input_ref | inputs]}}
  end

  defp lower_mapping!(%Mapping{source: %Export{}}, _state) do
    raise ArgumentError,
          "bare graph Export sources are not supported by output-first commands; use graph[:name] for a captured stream, or Command.new/1 with an explicit graph"
  end

  defp lower_mapping!(other, _state) do
    raise ArgumentError,
          "expected a mapping with a stream reference or selection, got: #{inspect(other)}"
  end

  defp resolve_inputs!(input_refs, options) do
    case Keyword.fetch(options, :inputs) do
      {:ok, inputs} ->
        unique_inputs!(inputs)

      :error ->
        input_refs
        |> Enum.map(fn reference ->
          case reference.declaration do
            nil ->
              raise ArgumentError,
                    "unbound input reference; select streams from Input.new/2 declarations, bind graph inputs, or supply an explicit ordered :inputs list"

            declaration ->
              declaration
          end
        end)
        |> unique_inputs!()
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
end
