defmodule FF.Graph.Export do
  @moduledoc """
  Opaque handle for one stream exported by a graph.

  Output callbacks receive graph exports in the first argument:

      command(
        "input.mp4",
        fn src -> src[:video] |> scale(w: 1280, h: -1) end,
        fn video ->
          FF.output("out.mp4", video: video, "c:v": :libx264)
        end
      )

  You normally pass exports to `FF.output/2`; constructing this struct directly
  is not part of the public API.
  """

  @type name :: atom() | String.t()

  @opaque t :: %__MODULE__{name: name() | nil, ref: term()}

  defstruct [:name, :ref]
end
