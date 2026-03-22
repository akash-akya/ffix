defmodule FF.Runner.Result do
  @moduledoc """
  Result of running an external command through `FF.Runner`.

  `stdout` and `stderr` only include the data requested by the runner options.
  `argv` and `shell` always reflect the exact command that was executed.
  Parsed ffmpeg-style logs and the latest progress update are exposed separately
  from the raw stderr capture.
  """

  alias FF.Command
  alias FF.Runner.Log
  alias FF.Runner.Progress

  @type exit_status :: non_neg_integer() | :epipe

  @type t :: %__MODULE__{
          command: Command.t() | nil,
          argv: [String.t()],
          shell: String.t(),
          exit_status: exit_status() | nil,
          stdout: binary() | nil,
          stderr: binary() | nil,
          logs: [Log.t()],
          last_progress: Progress.t() | nil,
          started_at: DateTime.t() | nil,
          finished_at: DateTime.t() | nil,
          duration_ms: non_neg_integer() | nil
        }

  defstruct [
    :command,
    :argv,
    :shell,
    :exit_status,
    :stdout,
    :stderr,
    :last_progress,
    :started_at,
    :finished_at,
    :duration_ms,
    logs: []
  ]
end
