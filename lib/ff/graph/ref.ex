defmodule FF.Graph.Ref do
  @moduledoc """
  Reference to a specific output pad of a graph node.
  """

  alias FF.Graph

  @type t :: %__MODULE__{
          node_id: Graph.node_id(),
          output: non_neg_integer()
        }

  defstruct [:node_id, :output]
end
