defmodule FFix.Discovery.Error do
  @moduledoc """
  A metadata parsing or discovery failure.

  `reason` identifies the failure. Parse errors include `line` and `text`;
  subprocess errors include `argv`, `exit_status`, and captured `output` when
  available. `:help_unavailable` means a registered component has no help
  exposed by FFmpeg, not that the component is absent.
  """

  defexception [:message, :reason, :line, :text, :argv, :exit_status, :output]

  @type t :: %__MODULE__{
          message: String.t(),
          reason: atom(),
          line: pos_integer() | nil,
          text: String.t() | nil,
          argv: [String.t()] | nil,
          exit_status: term(),
          output: binary() | nil
        }
end
