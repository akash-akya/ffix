defmodule FFix.Runner.Log do
  @moduledoc """
  One parsed ffmpeg-style log line emitted by `FFix.Runner`.
  """

  @type level :: :panic | :fatal | :error | :warning | :info | :verbose | :debug | :trace

  @type t :: %__MODULE__{
          level: level(),
          message: String.t(),
          raw: String.t()
        }

  defstruct [:level, :message, :raw]
end
