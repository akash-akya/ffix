defmodule FFix.Graph.Bind do
  @moduledoc false

  alias FFix.Command.Input
  alias FFix.Graph
  alias FFix.Graph.{Builder, InputRef, Merge, Node, Ref, StreamRef, Validator}

  def bind(%Graph{} = template, bindings) do
    Validator.graph!(template, allow_unused: true)
    bindings = normalize_bindings!(bindings)
    ports = selectors_by_input(template)
    initial = {Merge.new(template.settings), %{}, []}

    {graph, replacements, used} =
      Enum.reduce(Graph.nodes(template), initial, fn node, {graph, replacements, used} ->
        if node.kind == :input do
          {stream, keys} = resolve_binding!(node.input_ref, bindings, ports)
          {graph, _inputs} = Merge.add(graph, stream.graph)
          used = keys ++ used

          {graph, Map.put(replacements, node.id, stream.ref), used}
        else
          cloned = %{
            node
            | id: make_ref(),
              inputs: Enum.map(node.inputs, &replace_ref(&1, replacements))
          }

          graph = %{
            graph
            | nodes: Map.put(graph.nodes, cloned.id, cloned),
              order: graph.order ++ [cloned.id]
          }

          graph =
            if Node.sink?(cloned) do
              %{graph | terminals: graph.terminals ++ [cloned.id]}
            else
              graph
            end

          {graph, Map.put(replacements, node.id, cloned.id), used}
        end
      end)

    unused = Map.keys(bindings) -- used

    if unused != [] do
      raise ArgumentError, "unknown graph input bindings: #{inspect(unused)}"
    end

    exports =
      Enum.map(template.exports, fn export ->
        ref = replace_ref(export.ref, replacements)
        media = Enum.fetch!(graph.nodes[ref.node_id].output_media, ref.output)
        %{export | graph_id: graph.id, ref: ref, media: media}
      end)

    %{graph | exports: exports}
  end

  defp replace_ref(ref, replacements) do
    case Map.fetch!(replacements, ref.node_id) do
      %Ref{} = bound_pad -> bound_pad
      node_id -> %{ref | node_id: node_id}
    end
  end

  defp selectors_by_input(graph) do
    graph
    |> Graph.nodes()
    |> Enum.filter(&(&1.kind == :input))
    |> Enum.group_by(& &1.input_ref.input, & &1.input_ref.selector)
    |> Map.new(fn {input, selectors} -> {input, Enum.uniq(selectors)} end)
  end

  defp resolve_binding!(input_ref, bindings, ports) do
    keys =
      Enum.filter(
        [{input_ref.input, input_ref.selector}, input_ref.input],
        &Map.has_key?(bindings, &1)
      )

    value =
      case keys do
        [] -> input_ref.declaration
        [key] -> Map.fetch!(bindings, key)
        _ -> raise ArgumentError, "multiple bindings for graph input #{inspect(input_ref)}"
      end

    if is_struct(value, StreamRef) and keys == [input_ref.input] and
         length(ports[input_ref.input]) > 1 do
      raise ArgumentError,
            "input #{inspect(input_ref.input)} has multiple selectors; bind an Input declaration or exact {input, selector} slots"
    end

    stream =
      case value do
        %Input{} ->
          Builder.input(value, input_ref.selector)

        %StreamRef{} ->
          StreamRef.node!(value)
          value

        nil ->
          raise ArgumentError, "unbound graph input: #{inspect(input_ref.input)}"

        _ ->
          raise ArgumentError,
                "graph inputs bind to Input declarations or StreamRefs, got: #{inspect(value)}"
      end

    expected = InputRef.media(input_ref.selector)

    if expected != :unknown and stream.media not in [:unknown, expected] do
      raise ArgumentError, "graph input expects #{expected}, got: #{stream.media}"
    end

    {stream, keys}
  end

  defp normalize_bindings!(bindings) when is_map(bindings) or is_list(bindings) do
    Enum.reduce(bindings, %{}, fn
      {key, value}, result ->
        key =
          case key do
            {input, selector} ->
              {InputRef.normalize_input_id!(input), InputRef.normalize_selector!(selector)}

            input ->
              InputRef.normalize_input_id!(input)
          end

        if Map.has_key?(result, key) do
          raise ArgumentError, "duplicate graph input binding: #{inspect(key)}"
        end

        Map.put(result, key, value)

      other, _ ->
        raise ArgumentError, "invalid graph binding: #{inspect(other)}"
    end)
  end

  defp normalize_bindings!(_bindings) do
    raise ArgumentError, "graph bindings must be a map or ordered list of pairs"
  end
end
