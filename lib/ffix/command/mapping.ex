defmodule FFix.Command.Mapping do
  @moduledoc """
  An output's choice of source and encoding.

  `FFix.Encoder` helpers and `FFix.stream_copy/1` create mappings for you.
  `FFix.output/3` wraps bare streams in mappings using FFmpeg's default encoding.
  Use `new/2` when building mappings directly or reusing an encoder configuration.

  A mapping has a `source`, an `encoding`, and an optional output-local `name`.
  Encoding is an `FFix.Encoder` configuration, `:copy`, or `nil` for FFmpeg's
  defaults. See `FFix.Command.Output` for names and option callbacks.

  ## Encoding several tracks

  A mapping of `FFix.audio(input, :all)` can create several audio tracks. The
  same encoding applies to every selected track. Different settings need
  separately indexed selections:

      alias FFix.Encoder
      source = FFix.input("interview.mkv")

      output =
        FFix.output([
          FFix.stream_copy(FFix.audio(source, :all)),
          Encoder.libx264(FFix.video(source, 0), crf: 20),
          Encoder.libx264(FFix.video(source, 0), crf: 28)
        ], "qualities.mkv")

      FFix.command(output)

  Both video settings follow their respective mappings, even though the audio
  selection's track count is unknown. FFix uses video-relative option scopes
  in this case. When every mapping selects one stream, it uses absolute output
  indexes. Indexes restart for each destination.

  Within a media type, broad selections must share the same encoding policy
  and options. Mixing all-audio copy with an individually encoded audio track
  is ambiguous; select each audio track explicitly instead. Whole-input and
  raw-string queries have unknown media, so layouts containing them support
  leaving every mapping unconfigured or copying every mapping.

  Reusing a direct input stream creates another output use with its own
  encoding. To reuse a filtered stream, first branch it with
  `FFix.Filter.split/2` or `FFix.Filter.asplit/2`.
  """

  alias FFix.Graph.StreamRef

  @type t :: %__MODULE__{
          source: FFix.Command.source(),
          name: atom() | nil,
          encoding: FFix.Encoder.t() | :copy | nil
        }

  defstruct [:source, :encoding, :name]

  @doc """
  Pairs a source with an encoder configuration, `:copy`, or FFmpeg's defaults (`nil`).

      encoder = FFix.Encoder.new("libx264", crf: 20)
      FFix.Command.Mapping.new(video, encoder)

  Returns a mapping for `FFix.output/3`. Graph connectivity and stream-copy
  compatibility with filtering are checked when assembling the command.
  """
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
