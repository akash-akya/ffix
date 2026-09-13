defmodule FFix.Runner.Progress do
  @moduledoc """
  One ffmpeg `-progress` update, grouped through its `progress=continue` or
  `progress=end` marker. Fields without a closing marker are not emitted.

  The common fields are exposed directly, while the original key/value payload is
  kept in `fields` for callers that need something more specific.
  """

  @type status :: :continue | :end

  @type t :: %__MODULE__{
          status: status() | nil,
          frame: non_neg_integer() | nil,
          fps: float() | nil,
          bitrate: String.t() | nil,
          total_size: non_neg_integer() | nil,
          out_time_us: non_neg_integer() | nil,
          out_time_ms: non_neg_integer() | nil,
          out_time: String.t() | nil,
          dup_frames: non_neg_integer() | nil,
          drop_frames: non_neg_integer() | nil,
          speed: float() | nil,
          fields: map()
        }

  defstruct [
    :status,
    :frame,
    :fps,
    :bitrate,
    :total_size,
    :out_time_us,
    :out_time_ms,
    :out_time,
    :dup_frames,
    :drop_frames,
    :speed,
    fields: %{}
  ]
end
