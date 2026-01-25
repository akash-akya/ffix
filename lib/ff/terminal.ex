defmodule FF.Terminal do
  @moduledoc """
  Opaque handle for a sink-ending pipeline.
  """

  @opaque t :: %__MODULE__{
            plan: term(),
            media: :audio | :video | :unknown | nil
          }

  defstruct [:plan, :media]
end
