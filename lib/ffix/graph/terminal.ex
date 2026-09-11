defmodule FFix.Graph.Terminal do
  @moduledoc """
  Opaque handle for a sink-ending pipeline.

  Terminal values are produced by sink filters and can be attached to a graph
  with `FFix.graph(terminals: [...])` when a branch is meant to end inside the
  filtergraph instead of becoming an output mapping.
  """

  @opaque t :: %__MODULE__{
            plan: term(),
            media: :audio | :video | :unknown | nil
          }

  defstruct [:plan, :media]
end
