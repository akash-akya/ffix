defmodule FFix.Command.Mapping do
  @moduledoc """
  One output's use of an existing source.

  `source` accepts one stream reference or an unresolved `FFix.Selection`.
  Canonical graph exports require `FFix.Command.new/1` with an explicit graph.
  `encoding` is nil for FFmpeg's defaults, :copy, or an `FFix.Encoder` value.

      %FFix.Command.Mapping{
        source: FFix.video(input, 0),
        encoding: %FFix.Encoder{name: "libx264", options: [{"crf", 18}]}
      }

  `name` optionally identifies this mapping within its output. Named source
  bindings set it without changing the original mapping value. Names must be
  unique within an output and are not FFmpeg filter labels.

  A selection may create several output streams. Uniform copy or media-wide
  encoding can be scoped without enumerating them; ambiguous same-media policies
  require explicit stream indexes. One mapping is not necessarily one track.

  Direct input sources can be mapped repeatedly with different configurations.
  Actual filter outputs must be mapped exactly once and cannot use stream copy;
  split filtered frames explicitly when multiple consumers are needed.
  """

  alias FFix.Graph.StreamRef

  @type t :: %__MODULE__{
          source: FFix.Command.source(),
          name: atom() | nil,
          encoding: FFix.Encoder.t() | :copy | nil
        }

  defstruct [:source, :encoding, :name]

  @doc "Builds a mapping from an existing source reference; graph and copy checks run on the command."
  @spec new(FFix.Command.source(), FFix.Encoder.t() | :copy | nil) :: t()
  def new(source, encoding \\ nil) do
    case source do
      %StreamRef{} ->
        :ok

      %FFix.Graph.Export{} ->
        :ok

      %FFix.Selection{} = selection ->
        FFix.Selection.validate!(selection)

      other ->
        raise ArgumentError, "expected a stream reference or selection, got: #{inspect(other)}"
    end

    %__MODULE__{source: source, encoding: encoding}
  end
end
