defmodule FFix.Runner.Result do
  @moduledoc """
  The outcome and captured output of an execution.

  `FFix.run/2` returns this value on success. On failure, it is available as
  the `result` field of `FFix.Runner.Error`. Streaming includes it in the exit event.

  - `exit_status` — zero for success; a non-zero status for failure.
  - `stdout`, `stderr` — captured bytes according to `FFix.Runner.run/2` options;
    `nil` when discarded.
  - `last_progress` — latest parsed progress update, when available.
  - `argv`, `shell` — the executed arguments and their shell-quoted representation.
  - `command` — original command data, or `nil` for raw argv.
  - `started_at`, `finished_at`, `duration_ms` — execution timing.

  Full stderr collection retains all diagnostic output in memory; use a bounded
  tail for long-running commands. Stderr is preserved as raw bytes, not parsed logs.
  """

  alias FFix.Command
  alias FFix.Runner.Progress

  @type exit_status :: non_neg_integer()

  @type t :: %__MODULE__{
          command: Command.t() | nil,
          argv: [String.t()],
          shell: String.t(),
          exit_status: exit_status() | nil,
          stdout: binary() | nil,
          stderr: binary() | nil,
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
    :duration_ms
  ]
end
