defmodule FFix.Runner.Result do
  @moduledoc """
  Result of running an external command through `FFix.Runner`.

  `stdout` and `stderr` only include the data requested by the runner options.
  `argv` and `shell` always reflect the exact command that was executed.
  Parsed ffmpeg-style logs and the latest progress update are exposed separately
  from the raw stderr capture.

  `logs_truncated` indicates logs omitted by the stderr retention policy.
  `diagnostics_truncated` indicates oversized lines or progress records dropped
  by the parser. Such records are omitted, not emitted as complete diagnostics.
  With `stderr: :collect`, both raw and parsed diagnostics are unbounded.
  """

  alias FFix.Command
  alias FFix.Runner.Log
  alias FFix.Runner.Progress

  @type exit_status :: non_neg_integer() | :epipe

  @type t :: %__MODULE__{
          command: Command.t() | nil,
          argv: [String.t()],
          shell: String.t(),
          exit_status: exit_status() | nil,
          stdout: binary() | nil,
          stderr: binary() | nil,
          logs: [Log.t()],
          logs_truncated: boolean(),
          diagnostics_truncated: boolean(),
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
    logs: [],
    logs_truncated: false,
    diagnostics_truncated: false
  ]
end
