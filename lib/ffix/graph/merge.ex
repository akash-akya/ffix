defmodule FFix.Graph.Merge do
  @moduledoc false

  alias FFix.Graph
  alias FFix.Graph.{Node, Validator}

  def new(settings \\ []) do
    graph = %Graph{id: make_ref(), settings: settings}
    Validator.graph!(graph, allow_unused: true)
  end

  def merge(graphs, settings \\ []) do
    Enum.reduce(graphs, new(settings), fn graph, merged ->
      {merged, _inputs} = add(merged, graph)
      merged
    end)
  end

  # Exports belong to the caller's result, not to the fragments being combined.
  # Return newly encountered inputs so commands can interleave query dependencies.
  def add(%Graph{} = merged, %Graph{} = graph) do
    Validator.graph!(graph, allow_unused: true)

    {nodes, added, inputs} =
      Enum.reduce(graph.order, {merged.nodes, [], []}, fn node_id, {nodes, added, inputs} ->
        node = Map.fetch!(graph.nodes, node_id)

        case Map.fetch(nodes, node_id) do
          {:ok, ^node} ->
            {nodes, added, inputs}

          {:ok, _different} ->
            raise ArgumentError, "conflicting definitions for the same filter/input identity"

          :error ->
            inputs =
              if node.kind == :input do
                [node.input_ref | inputs]
              else
                inputs
              end

            {Map.put(nodes, node_id, node), [node_id | added], inputs}
        end
      end)

    added = Enum.reverse(added)

    sinks = Enum.filter(added, &Node.sink?(nodes[&1]))

    merged = %{
      merged
      | nodes: nodes,
        order: merged.order ++ added,
        terminals: merged.terminals ++ sinks,
        settings: merge_settings(merged.settings, graph.settings)
    }

    {merged, Enum.reverse(inputs)}
  end

  defp merge_settings(left, right) do
    Enum.reduce(right, left, fn {key, value} = setting, settings ->
      existing = Enum.find(settings, fn {name, _value} -> to_string(name) == to_string(key) end)

      case existing do
        nil -> settings ++ [setting]
        {_name, ^value} -> settings
        _different -> raise ArgumentError, "conflicting graph setting: #{key}"
      end
    end)
  end
end
