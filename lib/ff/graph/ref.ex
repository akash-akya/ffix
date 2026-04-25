defmodule FF.Graph.Ref do
  @moduledoc false

  alias FF.Graph

  @type t :: %__MODULE__{
          node_id: Graph.node_id(),
          output: non_neg_integer()
        }

  defstruct [:node_id, :output]
end
