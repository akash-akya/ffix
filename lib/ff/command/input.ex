defmodule FF.Command.Input do
  @moduledoc """
  One ffmpeg input declaration.

  ## Examples

      FF.Command.input("input.mp4", ss: "00:00:03")
      FF.Command.input("logo.png", loop: 1, framerate: 1)
  """

  @type source :: String.t() | :stdin | {:pipe, non_neg_integer()} | {:url, String.t()}
  @type option :: {atom() | String.t(), term()}

  @type t :: %__MODULE__{
          source: source(),
          options: [option()],
          metadata: map()
        }

  defstruct [:source, options: [], metadata: %{}]
end
