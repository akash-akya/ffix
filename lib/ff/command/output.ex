defmodule FF.Command.Output do
  @moduledoc """
  One ffmpeg output declaration.
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
