defmodule FF.Expr do
  @moduledoc """
  Wrapper for raw ffmpeg expressions.
  """

  @type t :: %__MODULE__{source: String.t()}

  defstruct [:source]
end
