defmodule FFix.Graph.Export do
  @moduledoc """
  Canonical exported-pad handle inside materialized graph data.

  The `graph.exports` field contains these handles for low-level `FFix.Command.new/1`
  construction with an explicit graph. Graph identity prevents using a foreign
  handle merely because its local pad address happens to match.

  For ordinary composition, `FFix.Graph.exports/1` and graph Access return
  filterable `FFix.Graph.StreamRef` values instead.
  """

  @type name :: atom() | String.t()
  @opaque t :: %__MODULE__{
            graph_id: reference(),
            name: name() | nil,
            ref: term(),
            media: FFix.Graph.StreamRef.media()
          }

  defstruct [:graph_id, :name, :ref, media: :unknown]
end
