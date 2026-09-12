defmodule FFix.Graph.Terminal do
  @moduledoc """
  Opaque reference to a sink in an immutable graph.

  Pass terminal values to `FFix.graph(terminals: [...])` or `FFix.command/2`.
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
