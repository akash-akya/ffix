defmodule FF.Expr do
  @moduledoc """
  Raw ffmpeg expression value.

  Use `FF.expr/1` when a filter option should be treated as ffmpeg expression
  syntax rather than ordinary text.

      video
      |> FF.Filter.drawtext(text: "Hello", x: FF.expr("w-tw-20"), y: 20)
  """

  @type t :: %__MODULE__{source: String.t()}

  defstruct [:source]
end
