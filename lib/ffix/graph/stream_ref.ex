defmodule FFix.Graph.StreamRef do
  @moduledoc """
  Opaque reference to one required input stream or one filter output.

  Indexed input helpers return references; broad or optional selections do not.
  Low-level graph inputs can also match one filter pad without naming an index.
  Filters consume references and return new ones. Reusable graph exports carry
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
