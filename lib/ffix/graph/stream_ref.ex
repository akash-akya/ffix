defmodule FFix.Graph.StreamRef do
  @moduledoc """
  Opaque reference to an input selection or a filter output.

  References describe connections, not running streams or encoded tracks.
  Select inputs with `FFix.video/2`, `FFix.audio/2`, or `FFix.select/2`; filters
  consume references and return new ones. Reusable graph exports also carry
  their graph's other roots and settings so composing one cannot lose a branch.
  """

  @type media :: :audio | :video | :subtitle | :data | :attachment | :unknown
  @type context :: %{id: reference(), roots: [t() | FFix.Graph.Terminal.t()], settings: list()}
  @opaque t :: %__MODULE__{
            plan: term(),
            output: non_neg_integer(),
            media: media(),
            context: context() | nil
          }

  defstruct [:plan, :output, :media, :context]
end
