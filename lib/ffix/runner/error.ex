defmodule FFix.Runner.Error do
  @moduledoc """
  An FFmpeg process that failed to start, finish successfully, or exchange data.

  `kind` is `:spawn`, `:exit`, or `:io`. The `message` is suitable for logs, and
  `result` contains captured diagnostics. `exit_status` is available when the
  process produced one. See `FFix.Runner.Result` for its fields.

  `FFix.run/2` returns `{:error, error}`. `FFix.run!/2` raises this exception.
  Exceptions from your own callbacks and stream consumers propagate separately.
  """

  alias FFix.Runner.Result

  @type kind :: :spawn | :exit | :io

  @type t :: %__MODULE__{
          kind: kind(),
          message: String.t(),
          exit_status: Result.exit_status() | nil,
          result: Result.t()
        }

  defexception [:kind, :message, :exit_status, :result]

  @doc false
  @spec spawn(String.t(), Result.t()) :: t()
  def spawn(reason, %Result{} = result) do
    %__MODULE__{
      kind: :spawn,
      result: result,
      message: "failed to start command: #{reason}\ncommand: #{result.shell}",
      exit_status: nil
    }
  end

  @doc false
  @spec exit(Result.t()) :: t()
  def exit(%Result{exit_status: exit_status} = result) do
    %__MODULE__{
      kind: :exit,
      result: result,
      exit_status: exit_status,
      message: build_exit_message(result)
    }
  end

  @doc false
  @spec io(String.t(), Result.t()) :: t()
  def io(reason, %Result{} = result) do
    %__MODULE__{
      kind: :io,
      result: result,
      message: "command I/O failed: #{reason}\ncommand: #{result.shell}"
    }
  end

  defp build_exit_message(%Result{exit_status: exit_status, shell: shell, stderr: stderr}) do
    base = "command exited with status #{inspect(exit_status)}\ncommand: #{shell}"

    case stderr do
      nil -> base
      "" -> base
      stderr -> base <> "\nstderr:\n" <> stderr
    end
  end
end
