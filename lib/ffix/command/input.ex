defmodule FFix.Command.Input do
  @moduledoc """
  Declare media sources and select their streams.

  Create an input with `FFix.input/2` or `new/2`. A file may contain video,
  several audio tracks, subtitles, and other streams. Select the tracks you
  want before applying filters or declaring outputs.

  ## Select tracks

      source = FFix.input("interview.mp4")
      picture = FFix.video(source, 0)
      sound = FFix.audio(source, 0)
      output = FFix.output([picture, sound], "interview.mkv")

  Indexes start at zero within each media type. `audio(source, 1)` selects the
  second audio track, regardless of where video or subtitles occur in the file.
  `FFix.select(source, 3)` instead counts every stream in the file.

  Use `:all` to retain every track of a media type. `optional: true` lets FFmpeg
  omit a missing match, which is useful for files that may have no audio:

      sources = [
        FFix.stream_copy(FFix.video(source, 0)),
        FFix.stream_copy(FFix.audio(source, :all, optional: true))
      ]

      FFix.output(sources, "interview.mkv") |> FFix.command()

  An indexed, required selection can feed a filter. Broad, optional, and string
  selections return `FFix.Selection` values for output mapping. Their number of
  matches is determined by FFmpeg when it reads the input. Even a string like
  `"v:0"` is treated as a query; use `FFix.video(source, 0)` for a filter input.

  To find the tracks in a file, use
  [ffprobe](https://ffmpeg.org/ffprobe.html), for example
  `ffprobe -v error -show_streams interview.mp4`. `FFix.Discovery` describes the
  FFmpeg installation's capabilities rather than the contents of a media file.

  ## Reuse an input

  Reusing the same declaration across outputs opens the source once. Declare
  the same file twice when you need different input settings:

      opening = FFix.input("interview.mp4", ss: 0)
      ending = FFix.input("interview.mp4", ss: 120)

      outputs = [
        FFix.output(FFix.video(opening, 0), "opening.mp4", t: 10),
        FFix.output(FFix.video(ending, 0), "ending.mp4", t: 10)
      ]

      FFix.command(outputs)

  Configure seeking and `FFix.Decoder` options before selecting streams. A stream
  keeps the input configuration it was selected from, so selecting first and
  changing that input later creates conflicting configurations.

  ## Input formats and options

  FFmpeg usually detects file formats. Use `FFix.Demuxer` when a format needs
  explicit settings, such as raw frame dimensions. `FFix.Decoder` configures
  how individual tracks are decoded.

  General input options are written before this source's `-i`. For example,
  `ss: 30` seeks before decoding. See `FFix.Command` for option syntax and the
  [FFmpeg input options](https://ffmpeg.org/ffmpeg.html#Main-options) for their meaning.
  """

  alias FFix.Decoder
  alias FFix.Demuxer
  alias FFix.Graph.Builder
  alias FFix.Graph.InputRef
  alias FFix.Graph.StreamRef
  alias FFix.Options
  alias FFix.Selection

  @type source :: String.t() | :stdin | {:pipe, non_neg_integer()} | {:url, String.t()}
  @type option :: {atom() | String.t(), term()}
  @type media :: :video | :audio | :subtitle | :data | :attachment
  @type decoder_selector :: {media(), non_neg_integer()} | {:index, non_neg_integer()}
  @type selector :: non_neg_integer() | :all | String.t()
  @type selection_option :: {:optional, boolean()}

  @type t :: %__MODULE__{
          source: source(),
          id: reference() | nil,
          options: [option()],
          demuxer: FFix.Demuxer.t() | nil,
          decoders: %{decoder_selector() => FFix.Decoder.t()}
        }

  defstruct [:source, :id, :demuxer, options: [], decoders: %{}]

  @doc """
  Declares a file, URL, or pipe source and its options.

      FFix.Command.Input.new("interview.mp4", ss: 30)
      FFix.Command.Input.new({:url, "https://example.com/interview.mp4"})
      FFix.Command.Input.new(:stdin, f: "image2pipe")

  Sources can be path/URL strings, `{:url, url}`, `:stdin`, or `{:pipe, descriptor}`.
  Use `FFix.Runner`'s `stdin:` option to supply bytes to `:stdin`.

  `demuxer:` accepts a `FFix.Demuxer` configuration. `decoders:` accepts a map of
  indexed selectors to `FFix.Decoder` configurations. Remaining options are
  general FFmpeg input controls; callbacks are supported on outputs only.
  """
  @spec new(source(), [option()]) :: t()
  def new(source, options \\ []) do
    {configuration, raw_options} = Options.split!(options, [:demuxer, :decoders])

    if List.keymember?(raw_options, :label, 0) do
      raise ArgumentError, "input labels are not supported; bind named graph inputs explicitly"
    end

    input = %__MODULE__{
      id: make_ref(),
      source: source,
      options: raw_options,
      demuxer: Keyword.get(configuration, :demuxer),
      decoders: Keyword.get(configuration, :decoders, %{})
    }

    validate!(input)
  end

  @doc false
  def validate!(%__MODULE__{} = input) do
    Options.validate_endpoint!(input.source, :input)
    Options.validate_cli!(input.options)

    unless is_nil(input.id) or is_reference(input.id) do
      raise ArgumentError, "input identity must be a reference or nil"
    end

    case input.demuxer do
      nil ->
        :ok

      %Demuxer{} = demuxer ->
        Options.validate_component!(demuxer)
        Options.reject_conflicts!(input.options, :demuxer, [demuxer])

      other ->
        raise ArgumentError, "invalid demuxer configuration: #{inspect(other)}"
    end

    unless is_map(input.decoders) and not is_struct(input.decoders) do
      raise ArgumentError, "input decoders must be a map of indexed selectors to Decoder values"
    end

    namespaces =
      Enum.map(input.decoders, fn {selector, decoder} ->
        validate_decoder!(selector, decoder)

        case selector do
          {:index, _index} -> :absolute
          {_media, _index} -> :media_relative
        end
      end)

    if length(Enum.uniq(namespaces)) > 1 do
      raise ArgumentError, "cannot mix absolute and media-relative decoder selectors on one input"
    end

    if map_size(input.decoders) > 0 do
      Options.reject_conflicts!(input.options, :decoding, Map.values(input.decoders))
    end

    input
  end

  def validate!(other), do: raise(ArgumentError, "invalid command input: #{inspect(other)}")

  @doc false
  def validate_decoder!(selector, decoder) do
    unless InputRef.single?(selector) and
             elem(selector, 0) in [:video, :audio, :subtitle, :data, :attachment, :index] do
      raise ArgumentError,
            "decoder selector must be {media, nonnegative_index} or {:index, nonnegative_index}, got: #{inspect(selector)}"
    end

    case decoder do
      %Decoder{} -> Options.validate_component!(decoder)
      other -> raise ArgumentError, "invalid decoder configuration: #{inspect(other)}"
    end
  end

  @doc """
  Selects an absolute stream index, all streams, or an FFmpeg stream specifier.

      FFix.Command.Input.select(source, "a:m:language:eng", optional: true)

  An integer returns a required stream reference with unknown media type.
  `:all`, strings, and `optional: true` return output selections. See
  `FFix.select/3` for examples and the module guide for media-relative indexes.
  """
  @spec select(t(), selector(), [selection_option()]) :: StreamRef.t() | Selection.t()
  def select(%__MODULE__{} = input, selector, options \\ []) do
    selector =
      case selector do
        index when is_integer(index) and index >= 0 ->
          {:index, index}

        :all ->
          :all

        raw when is_binary(raw) ->
          {:raw, raw}

        other ->
          raise ArgumentError,
                "invalid input selector: #{inspect(other)}; use an absolute index, :all, or a raw string"
      end

    selection(input, selector, selection_options!(options, [:optional]))
  end

  @doc false
  def select_media(%__MODULE__{} = input, media, index, options \\ []) do
    allowed =
      if media == :video do
        [:optional, :attached_pictures]
      else
        [:optional]
      end

    options = selection_options!(options, allowed)

    media =
      if media == :video and not Keyword.get(options, :attached_pictures, true) do
        :video_only
      else
        media
      end

    selection(input, {media, index}, options)
  end

  defp selection(input, selector, options) do
    selector = InputRef.normalize_selector!(selector)
    optional = Keyword.get(options, :optional, false)

    if InputRef.single?(selector) and not optional do
      Builder.input(input, selector)
    else
      Selection.new(input, selector, optional)
    end
  end

  defp selection_options!(options, allowed) do
    {controls, unknown} = Options.split!(options, allowed)

    if unknown != [] do
      raise ArgumentError, "unknown selection options: #{inspect(unknown)}"
    end

    Enum.each(controls, fn {name, value} ->
      unless is_boolean(value) do
        raise ArgumentError, "#{name} must be a boolean"
      end
    end)

    controls
  end
end
