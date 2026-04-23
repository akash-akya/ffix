defmodule FF.Command.Output do
  @moduledoc """
  One ffmpeg output declaration.

  `sources` is the ordered list of graph exports or input streams that become
  `-map` entries. `options` is a flat keyword/list of ffmpeg output options and
  is rendered after the maps and before the output target.

  The public `FF.output/2` helper accepts media-role options such as `video:`
  and `audio:` and lowers them into this source list. Use `sources:` when exact
  map ordering matters.
  """

  alias FF.Command

  @type target :: String.t() | :stdout | {:pipe, non_neg_integer()} | {:url, String.t()}
  @type option :: {atom() | String.t(), term()}

  @type t :: %__MODULE__{
          target: target(),
          sources: [Command.source()],
          options: [option()]
        }

  defstruct [:target, sources: [], options: []]
end
