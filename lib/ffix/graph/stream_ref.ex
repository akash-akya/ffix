defmodule FFix.Graph.StreamRef do
  @moduledoc """
  Opaque reference to one input stream or filter output in an immutable graph.

  References retain the graph's other branches, sinks, and settings. Broad and
  optional input selections use `FFix.Selection` instead.
  """

  @type media :: :audio | :video | :subtitle | :data | :attachment | :unknown
  @opaque t :: %__MODULE__{graph: FFix.Graph.t(), ref: FFix.Graph.Ref.t(), media: media()}
  defstruct [:graph, :ref, :media]

  @doc false
  def node!(%__MODULE__{graph: %{nodes: nodes}, ref: %FFix.Graph.Ref{} = ref, media: media})
      when is_map(nodes) do
    case Map.fetch(nodes, ref.node_id) do
      {:ok, %FFix.Graph.Node{output_media: outputs} = node}
      when is_list(outputs) and is_integer(ref.output) and ref.output >= 0 ->
        if Enum.fetch(node.output_media, ref.output) != {:ok, media} do
          raise ArgumentError, "invalid stream output pad #{inspect(ref.output)}"
        end

        node

      _ ->
        raise ArgumentError, "stream reference does not identify a graph output pad"
    end
  end

  def node!(_stream) do
    raise ArgumentError, "invalid stream reference"
  end
end
