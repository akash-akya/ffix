defmodule FFix.Graph.Export do
  @moduledoc """
  Opaque handle for one stream exported by a graph.

  Output callbacks receive graph exports in the first argument:

      FFix.command(
        "input.mp4",
        fn src -> src[:video] |> FFix.Filter.scale(w: 1280, h: -1) end,
        fn video ->
          FFix.output(video, "out.mp4", "c:v": :libx264)
        end
      )

  You normally pass exports to `FFix.output/2`; constructing this struct directly
  is not part of the public API.
  """

  @type name :: atom() | String.t()

  @opaque t :: %__MODULE__{
            graph_id: reference(),
            name: name() | nil,
            ref: term(),
            media: :video | :audio | :unknown
          }

  defstruct [:graph_id, :name, :ref, media: :unknown]
end
