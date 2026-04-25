defmodule FF.Stream do
  @moduledoc """
  Opaque handle for one stream produced by an input or filter.

  Streams are passed into filters, exported from graphs, or mapped to command
  outputs. Build them through input access or filter helpers rather than by
  constructing this struct directly.

      video = inputs.src[:video]
      preview = video |> FF.Filter.scale(w: 320, h: -1)
  """

  @opaque t :: %__MODULE__{
            plan: term(),
            output: non_neg_integer(),
            media: :audio | :video | :unknown
          }

  defstruct [:plan, :output, :media]
end
