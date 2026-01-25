defmodule FF.Graph.Export do
  @moduledoc """
  One stream exported from a graph.
  """

  alias FF.Graph.Ref

  @type t :: %__MODULE__{
          name: atom() | nil,
          ref: Ref.t()
        }

  defstruct [:name, :ref]
end
