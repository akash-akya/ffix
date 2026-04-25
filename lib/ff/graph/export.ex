defmodule FF.Graph.Export do
  @moduledoc """
  Opaque handle for one stream exported by a graph.

  Output callbacks receive graph exports in the first argument:

      outputs: fn graph ->
        FF.output("out.mp4", video: graph.main, "c:v": :libx264)
      end

  You normally pass exports to `FF.output/2`; constructing this struct directly
  is not part of the public API.
  """

  @type name :: atom() | String.t()

  @opaque t :: %__MODULE__{name: name() | nil, ref: term()}

  defstruct [:name, :ref]
end
