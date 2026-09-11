defmodule FFix.Graph.Expr do
  @moduledoc """
  Raw ffmpeg expression value.

  Use `FFix.expr/1` when a filter option should be treated as ffmpeg expression
  syntax rather than ordinary text.

      video
      |> FFix.Filter.drawtext(text: "Hello", x: FFix.expr("w-tw-20"), y: 20)
  """

  @type t :: %__MODULE__{source: String.t()}

  defstruct [:source]
end
