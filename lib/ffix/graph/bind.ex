defmodule FFix.Graph.Bind do
  @moduledoc false

  alias FFix.Command.Input
  alias FFix.Graph
  alias FFix.Graph.{Builder, InputRef, StreamRef}

  def bind(%Graph{} = graph, bindings) do
    Builder.validate_graph!(graph, allow_unused: true)
    bindings = normalize_bindings!(bindings)
    graph_id = make_ref()

    {nodes, used} =
      Enum.map_reduce(graph.order, MapSet.new(), fn node_id, used ->
        node = Map.fetch!(graph.nodes, node_id)
        node = %{node | identity: make_ref()}

        if node.kind == :input do
          input_ref = node.input_ref

          keys =
            Enum.filter(
              [{input_ref.input, input_ref.selector}, input_ref.input],
              &Map.has_key?(bindings, &1)
            )

          {binding, used} =
            case keys do
              [key] ->
                value = Map.fetch!(bindings, key)

                if is_struct(value, StreamRef) and key == input_ref.input and
                     multiple_selectors?(graph, key),
                   do:
                     raise(
                       ArgumentError,
                       "input #{inspect(key)} has multiple selectors; bind an Input declaration or exact {input, selector} slots"
                     )

                {value, MapSet.put(used, key)}

              [] ->
                {input_ref.binding || input_ref.declaration, used}

              _ ->
                raise ArgumentError, "multiple bindings for graph input #{inspect(input_ref)}"
            end

          binding = select_binding!(binding, input_ref)
          validate_media!(node.output_media, binding)
          {{node_id, %{node | input_ref: %{input_ref | binding: binding}}}, used}
        else
          {{node_id, node}, used}
        end
      end)

    unused = Map.keys(bindings) -- MapSet.to_list(used)
    if unused != [], do: raise(ArgumentError, "unknown graph input bindings: #{inspect(unused)}")

    instance = %{
      graph
      | id: graph_id,
        nodes: Map.new(nodes),
        exports: Enum.map(graph.exports, &%{&1 | graph_id: graph_id})
    }

    {streams, terminals} = Builder.graph_roots(instance)

    exports =
      Enum.zip_with(graph.exports, streams, fn export, stream -> {export.name, stream} end)

    Builder.graph(outputs: exports, terminals: terminals)
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

        if Map.has_key?(result, key),
          do: raise(ArgumentError, "duplicate graph input binding: #{inspect(key)}")

        Map.put(result, key, value)

      other, _ ->
        raise ArgumentError, "invalid graph binding: #{inspect(other)}"
    end)
  end

  defp normalize_bindings!(_bindings),
    do: raise(ArgumentError, "graph bindings must be a map or ordered list of pairs")

  defp multiple_selectors?(graph, input) do
    graph.nodes
    |> Map.values()
    |> Enum.filter(&(&1.kind == :input and &1.input_ref.input == input))
    |> Enum.map(& &1.input_ref.selector)
    |> Enum.uniq()
    |> length()
    |> Kernel.>(1)
  end

  defp select_binding!(%Input{} = input, input_ref), do: Builder.input(input, input_ref.selector)
  defp select_binding!(%StreamRef{} = stream, _input_ref), do: stream

  defp select_binding!(nil, input_ref),
    do:
      raise(
        ArgumentError,
        "unbound graph input: #{inspect(input_ref.input)} #{inspect(input_ref.selector)}"
      )

  defp select_binding!(other, _input_ref),
    do:
      raise(
        ArgumentError,
        "graph inputs bind to Input declarations or StreamRefs, got: #{inspect(other)}"
      )

  defp validate_media!([expected], %StreamRef{media: actual, plan: plan}) do
    if expected != :unknown and actual not in [:unknown, expected],
      do: raise(ArgumentError, "graph input expects #{expected}, got: #{actual}")

    if plan.kind == :input do
      selector = plan.input_ref.selector

      if selector == :all or match?({_media, :all}, selector),
        do: raise(ArgumentError, "graph inputs require one stream, not an all-stream selection")
    end
  end
end
