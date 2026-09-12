defmodule FFix.Graph.Terminal do
  @moduledoc """
  A filter branch that ends at a sink.

  Sink filters such as `FFix.Filter.anullsink/2` consume a stream and return a
  terminal. Include it in `FFix.command(outputs, terminals: [terminal])` to
  execute that branch, or store it in a graph with `FFix.graph/1`.

  See `FFix.Filter` for branching and `FFix.Graph.terminals/1` for retrieving
  sinks from a reusable graph.
  """

  @opaque t :: %__MODULE__{graph: FFix.Graph.t(), node_id: FFix.Graph.node_id()}
  defstruct [:graph, :node_id]

  @doc false
  def validate!(%__MODULE__{graph: graph, node_id: node_id} = terminal) do
    case Map.fetch(graph.nodes, node_id) do
      {:ok, %FFix.Graph.Node{kind: :filter, output_media: []}} -> terminal
      _ -> raise ArgumentError, "terminal must reference a sink node"
    end
  end
end
