defmodule FF.Graph.Export do
  @moduledoc """
  One stream exported from a graph.
  """

  alias FF.Graph.Ref

  @type name :: atom() | String.t()

  @type t :: %__MODULE__{
          name: name() | nil,
          ref: Ref.t()
        }

  defstruct [:name, :ref]
end
