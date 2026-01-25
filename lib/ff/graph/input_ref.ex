defmodule FF.Graph.InputRef do
  @moduledoc """
  Structured reference to an external ffmpeg input stream.
  """

  @type selector ::
          :video
          | :audio
          | {:video, non_neg_integer()}
          | {:audio, non_neg_integer()}
          | {:raw, String.t()}

  @type t :: %__MODULE__{
          input: non_neg_integer(),
          selector: selector()
        }

  defstruct [:input, :selector]
end
