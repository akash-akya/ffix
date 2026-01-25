defmodule FF.Command.Input do
  @moduledoc """
  One ffmpeg input declaration.
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
