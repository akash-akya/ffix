defmodule FFix.Graph.StreamRef do
  @moduledoc """
  A selected input stream or the result of a filter.

  Obtain a stream with an indexed helper such as `FFix.video/3`, a `FFix.Filter`
  function, or `FFix.Graph.export/2`. Pass it to another filter, an encoder, or
  an output. These functions manage the reference for you.

  A stream retrieved from a graph retains the graph's other branches. See
  `FFix.Graph` for keeping them connected, and `FFix.Selection` for output
  queries that may match several tracks.
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
