defmodule FF.Stream do
  @moduledoc """
  Opaque handle for one stream produced by an input or filter.
  """

  @opaque t :: %__MODULE__{
            plan: term(),
            output: non_neg_integer(),
            media: :audio | :video | :unknown
          }

  defstruct [:plan, :output, :media]
end
