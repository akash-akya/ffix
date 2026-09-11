defmodule FFix.Graph.StreamRef do
  @moduledoc """
  Opaque reference to an input selection or a filter output.

  References describe graph connections, not running streams or encoded output
  tracks. Filters consume references and produce new ones; output mappings
  declare how a reference is used, including encoding or packet copy.

  Build references through input access or filter helpers rather than by
  constructing this struct directly.

      video = src[:video]
      preview = video |> FFix.Filter.scale(w: 320, h: -1)
  """

  @opaque t :: %__MODULE__{
            plan: term(),
            output: non_neg_integer(),
            media: :audio | :video | :unknown
          }

  defstruct [:plan, :output, :media]
end
