defmodule FFix.Command.Mapping do
  @moduledoc """
  One output's use of an existing source.

  `source` accepts the same references as `FFix.Command.output/3`: direct input
  streams, graph exports, or graph export names/indexes. `encoding` is `nil` for
  no explicit configuration, `:copy` for stream copy, or an `FFix.Encoder` value.

      %FFix.Command.Mapping{
        source: input[video: 0],
        encoding: %FFix.Encoder{name: "libx264", options: [{"crf", 18}]}
      }

  `name` optionally identifies this mapping within its output. Named `sources:`
  bindings set it without changing the original mapping value. Names must be
  unique within an output and are not FFmpeg filter labels.

  Mapping order determines absolute stream indexes within each output. When
  any mapping has encoding configuration, every mapping in that output must
  select one stream: an indexed audio/video input or a filtered export. Broad
  and raw selectors remain available for unconfigured mappings with raw CLI
  options; they are never assumed to select exactly one stream.

  Direct input sources can be mapped repeatedly with different configurations.
  Actual filter outputs must be mapped exactly once and cannot use stream copy;
  split filtered frames explicitly when multiple consumers are needed.
  """

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
      %FFix.Stream{} ->
        :ok

      %FFix.Graph.Export{} ->
        :ok

      name when is_atom(name) and name not in [nil, true, false] ->
        :ok

      index when is_integer(index) and index >= 0 ->
        :ok

      other ->
        raise ArgumentError, "expected a stream or graph export source, got: #{inspect(other)}"
    end

    %__MODULE__{source: source, encoding: encoding}
  end
end
