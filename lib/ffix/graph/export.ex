defmodule FFix.Graph.Export do
  @moduledoc """
  An output handle for explicit command construction.

  The `exports` field of a graph contains these handles. Pair them with that
  same graph when constructing a command through `FFix.Command.new/1`.

  For normal pipeline composition, retrieve streams with `graph[:name]` or
  `FFix.Graph.exports/1`, then use `FFix.command/2`.
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
