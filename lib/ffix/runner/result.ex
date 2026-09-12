defmodule FFix.Runner.Result do
  @moduledoc """
  The outcome and captured output of an execution.

  `FFix.run/2` returns this value on success. On failure, it is available as
  the `result` field of `FFix.Runner.Error`. Streaming includes it in the exit event.

  - `exit_status` — zero for success; a non-zero status or `:epipe` for failure.
  - `stdout`, `stderr` — captured bytes according to `FFix.Runner.run/2` options;
    `nil` when discarded.
  - `logs` — retained `FFix.Runner.Log` entries.
  - `last_progress` — latest parsed progress update, when available.
  - `argv`, `shell` — the executed arguments and their shell-quoted representation.
  - `command` — original command data, or `nil` for raw argv.
  - `started_at`, `finished_at`, `duration_ms` — execution timing.

  `logs_truncated` reports logs omitted by the capture budget.
  `diagnostics_truncated` reports oversized lines or progress records that were
  dropped. Full stderr collection retains both raw and parsed diagnostics in
  memory; use a bounded tail for long-running commands.
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
