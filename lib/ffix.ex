defmodule FFix do
  @moduledoc """
  Build ffmpeg filtergraphs and commands from Elixir.

  The usual workflow is:

    * pass input sources to `command/2`
    * select streams with `video/1` and `audio/1`, then use `FFix.Filter` helpers
    * configure mappings with `FFix.Encoder` helpers or `stream_copy/1`
    * pass sources and a target to `output/3` or `FFix.Muxer` helpers
    * serialize with `to_argv/1` or execute with `run/2`

  `use FFix` imports the top-level helpers plus generated filter functions.
  Callbacks receive and return ordinary Elixir values. Examples in this module
  assume `use FFix`; without it, call `FFix` and `FFix.Filter` functions directly.

  ## Quick Start

      command("input.mp4", fn source ->
        cropped = source |> video() |> crop(w: 720, h: 720)

        [
          FFix.Encoder.libx264(cropped, crf: 18),
          FFix.Encoder.aac(audio(source), b: "128k")
        ]
        |> FFix.Muxer.mp4("square.mp4")
      end)

  This declares a cropped video encode and an audio encode in one MP4 output.
  Construction does not run FFmpeg. Generic codec/format functions forward
  options without implementation-specific metadata checks:

      source =
        "input.mp4"
        |> FFix.Demuxer.demux("mov")
        |> FFix.Decoder.decode("h264", {:video, 0}, threads: 2)

      command(source, fn input ->
        [
          FFix.Encoder.encode(video(input), "h264", crf: 23),
          stream_copy(audio(input))
        ]
        |> FFix.Muxer.mux("mp4", "out.mp4")
      end)

  Decoders always require an explicit stream selector. An encoder receives a
  selected stream; a decoder updates an input declaration at that stream index.

  ## Command Model

  A command stores ordered inputs, an optional filtergraph, ordered output
  mappings, and options. A file path is not itself a stream:

      src = input("input.mp4")
      video(src, 0)
      audio(src, 1)
      src[:video]
      src[:audio]

  Indexed selectors choose individual streams. Broad selectors such as
  `src[:audio]` retain FFmpeg's meaning of all matching streams. Filters consume
  streams and produce new streams:

      cropped = video(src) |> crop(w: 720, h: 720)
      output([cropped, audio(src)], "square.mp4")

  Sources always precede the output target. Their order is the `-map` order;
  media types come from the sources, not from `video:` or `audio:` option keys.
  Named bindings assign output-local names without changing track order:

      output([main: cropped, sound: audio(src)], "square.mp4")

  See `FFix.Command.Output` for deferred option callbacks using these names.
  Filter labels such as `[out0]` are generated implementation details, not names
  callers normally manage.

  ## Command Callbacks

  `command/2` collects the filter plans reachable from mapped output streams.
  Use separate graph/output callbacks when you need explicit graph exports,
  terminal sinks, or graph settings:

      command(
        "input.mp4",
        fn src ->
          [main, preview] = video(src) |> split(outputs: 2)
          [main: main, preview: scale(preview, w: 320, h: -2)]
        end,
        fn [main: main, preview: preview], src ->
          [
            output([main, audio(src)], "main.mp4"),
            output([preview], "thumb-%03d.jpg", f: :image2)
          ]
        end
      )

  Input and graph shapes are preserved at the callback boundary:

    * `stream -> export`
    * `[stream] -> [export]`
    * `[name: stream] -> [name: export]`
    * `%{name: stream} -> %{name: export}`

  Input sources are normalized to `%FFix.Command.Input{}` values. Graph callbacks
  may return `%FFix.Graph{}` values as well as streams or collections. Output
  callbacks accept graph exports alone, or graph exports and input declarations.

  ## Options

  Put options where FFmpeg expects them:

      command(
        input("input.mp4", ss: "00:00:05"),
        fn src -> scale(video(src), w: 1280, h: -2) end,
        fn picture, src ->
          output([picture, audio(src)], "out.mp4", "c:v": :libx264, "c:a": :copy)
        end,
        global: [y: true, loglevel: :error]
      )

    * global options precede inputs
    * input options precede `-i`
    * filter options belong to `-filter_complex`
    * output options precede their output target

  Raw options retain FFmpeg names, including quoted stream specifiers such as
  `"c:v"` and `"metadata:s:a:0"`. Structured decoder settings belong to inputs;
  encoder settings belong to mappings; muxer settings belong to outputs.
  Encoding indexes follow mapping order and restart for each output.

  Configured encoding requires every mapping to select one stream: an indexed
  input stream or a filtered export. Direct input streams can be copied;
  filtered streams must be encoded. Filtered outputs must be mapped exactly once;
  use `split` or `asplit` for multiple consumers. Do not combine structured
  configuration with conflicting raw codec, format, or mapping controls.

  ## API Layers

    * `FFix.command/2` builds commands with one output-producing callback.
    * `FFix.command/3` also supports separate graph and output callbacks.
    * `FFix.Command` constructs or transforms command structs directly.
    * `FFix.Graph` parses, serializes, and models filtergraphs.
    * `FFix.Runner` executes commands and streams events.

  `validate!/1` checks structure without probing media or executing FFmpeg.
  `to_argv/1` is the canonical serialization boundary; prefer argv over shell
  strings for execution.
  """
  @moduledoc groups: [
               "Setup",
               "Command building",
               "Inputs and outputs",
               "Filtergraphs",
               "Serialization",
               "Execution",
               "Validation"
             ]

  alias FFix.Command
  alias FFix.Expr
  alias FFix.Command.Build
  alias FFix.Filter.Builder
  alias FFix.Graph
  alias FFix.Runner
  alias FFix.Stream
  alias FFix.Terminal

  @doc group: "Setup"
  @doc """
  Imports the command, input/output, stream-selection, and filter helpers.

      defmodule Pipeline do
        use FFix

        def resize(video) do
          video |> scale(w: 1280, h: -1)
        end
      end

  Codec and format helpers remain module-qualified.
  """
  defmacro __using__(_options) do
    quote do
      import FFix,
        only: [
          command: 2,
          command: 3,
          command: 4,
          video: 1,
          video: 2,
          audio: 1,
          audio: 2,
          stream_copy: 1,
          expr: 1,
          graph: 1,
          input: 1,
          input: 2,
          output: 2,
          output: 3,
          shape: 2
        ]

      import FFix.Filter
    end
  end

  @doc group: "Inputs and outputs"
  @doc """
  Declares an input from a source and optional input options.

      input("clip.mp4", ss: "00:00:05", t: "00:00:10")
      input(:stdin, f: :wav)

  Raw options are rendered before `-i`. `demuxer:` accepts an `FFix.Demuxer`
  configuration; `decoders:` accepts a map of explicit stream selectors to
  `FFix.Decoder` configurations. For optionless inputs, `command/2` also accepts
  the source string directly.
  """
  @spec input(Command.Input.source(), [Command.option()]) :: Command.Input.t()
  def input(source, options \\ []), do: Command.input(source, options)

  @doc group: "Inputs and outputs"
  @doc "Selects one video stream by its media-relative index; defaults to the first video stream."
  @spec video(Command.Input.t(), non_neg_integer()) :: Stream.t()
  def video(%Command.Input{} = input, index \\ 0), do: input[video: index]

  @doc group: "Inputs and outputs"
  @doc "Selects one audio stream by its media-relative index; defaults to the first audio stream."
  @spec audio(Command.Input.t(), non_neg_integer()) :: Stream.t()
  def audio(%Command.Input{} = input, index \\ 0), do: input[audio: index]

  @doc group: "Inputs and outputs"
  @doc """
  Declares packet-level stream copy for one output occurrence.

  This is not the `FFix.Filter.copy/2` video filter. Filtered sources cannot use
  stream copy; command validation checks this after graph references are resolved.
  """
  @spec stream_copy(Command.source()) :: Command.Mapping.t()
  def stream_copy(source), do: Command.Mapping.new(source, :copy)

  @doc group: "Filtergraphs"
  @doc """
  Wraps a raw ffmpeg expression so it is serialized as an expression value.

      drawtext(video, text: "Hello", x: expr("w-tw-20"), y: 20)
  """
  @spec expr(String.t()) :: Expr.t()
  def expr(source) when is_binary(source), do: %Expr{source: source}

  @doc group: "Filtergraphs"
  @doc """
  Applies a filter by name.

  Most code should call generated helpers from `FFix.Filter`, such as
  `scale/2`, `overlay/3`, or `fps/2`. Use `filter/3` when the filter name is
  dynamic.

      FFix.filter(:scale, [video], w: 1280, h: -1)
  """
  @spec filter(atom() | String.t(), [Stream.t()], keyword()) ::
          Stream.t() | Terminal.t() | [Stream.t()] | tuple()
  def filter(name, inputs, options \\ []) when is_list(inputs) do
    Builder.filter(name, inputs, options)
  end

  @typedoc """
  Media type for a shaped filter output.
  """
  @type output_media :: :audio | :video | :unknown

  @doc group: "Filtergraphs"
  @doc """
  Assigns a concrete output shape to a dynamic or ambiguous filter result.

  Some ffmpeg filters have output counts or media types that depend on options.
  `shape/2` lets you state the result explicitly before exporting or mapping it.

      [audio, video] =
        input_audio
        |> ebur128(video: true)
        |> FFix.shape([:audio, :video])
  """
  @spec shape(Stream.t() | [Stream.t()] | tuple(), [output_media()]) ::
          Stream.t() | [Stream.t()]
  def shape(result, outputs), do: Builder.shape(result, outputs)

  @doc group: "Filtergraphs"
  @doc """
  Builds a `%FFix.Graph{}` from exported streams and terminal sinks.

  Common options:

    * `:output` - a single unnamed exported stream
    * `:outputs` - a list of named or unnamed exported streams
    * `:terminals` - sink-ending filter results, such as `nullsink`
    * `:settings` - graph-level settings such as `sws_flags`

  In `command/3`, graph callbacks can return streams, lists, keyword lists, or
  maps directly. Use `graph/1` when you need terminals or graph settings.

      FFix.graph(
        outputs: [main: video |> scale(w: 1280, h: -1)],
        settings: [sws_flags: [:accurate_rnd]]
      )
  """
  @spec graph(keyword()) :: Graph.t()
  def graph(options), do: Builder.graph(options)

  @doc group: "Inputs and outputs"
  @doc """
  Declares an output from explicit sources, a target, and optional CLI options.

      output([main, audio(src)], "out.mp4", "c:v": :libx264, "c:a": :aac)
      output([audio(src, 1), audio(src, 0)], "archive.mka", c: :copy)
      output([main: picture, sound: audio(src)], "out.mp4")

  Sources may be streams, graph exports or their names/indexes, configured
  mappings, or ordered lists of these. `{name, source}` pairs bind output-local
  names for option callbacks. At least one source is required; there are no
  `video:`, `audio:`, or `sources:` option shortcuts.

  Options are rendered after `-map` entries and before the target. Pass `muxer:`
  to attach an independent `FFix.Muxer` configuration, or use `FFix.Muxer` helpers
  to select a format. The target can be a path, URL, or pipe.
  """
  @spec output(Command.binding() | [Command.binding()], Command.Output.target(), [
          Command.option()
        ]) ::
          Command.Output.t()
  def output(sources, target, options \\ []), do: Command.output(sources, target, options)

  @doc group: "Command building"
  @doc "Returns an empty low-level command. Prefer `command/2` for the callback API."
  @spec command() :: Command.t()
  def command, do: Command.new()

  @doc false
  @spec command(keyword()) :: Command.t()
  def command(options) when is_list(options), do: Build.command(options)

  @doc group: "Command building"
  @doc """
  Builds a command from one callback returning an output or ordered output list.

  The callback receives normalized inputs in their original shape. Filter plans
  attached to mapped streams are collected into a graph; direct input mappings
  stay direct. Repeated filtered mappings are not implicitly split. Use
  `command/3` with separate graph/output callbacks for graph settings, terminal
  sinks, or explicit exports.

      command("input.mp4", fn source ->
        scaled = FFix.Filter.scale(video(source), w: 1280, h: -2)

        [FFix.Encoder.libx264(scaled, crf: 18), stream_copy(audio(source))]
        |> FFix.Muxer.mp4("out.mp4")
      end)

  Pass `global: [...]` as a third argument for command-level options. Construction
  does not run FFmpeg; use `to_argv/1` to inspect or `run/2` to execute.
  """
  @spec command(term(), (term() -> Command.Output.t() | [Command.Output.t()])) :: Command.t()
  def command(inputs, outputs_fun), do: Build.command(inputs, outputs_fun)

  @doc group: "Command building"
  @doc """
  Builds a command from inputs, a graph callback, and an output callback.

  Also accepts `command(inputs, output_callback, global: options)` for the
  one-callback form described in `command/2`.

      command(
        "input.mp4",
        fn src -> video(src) |> crop(w: 720, h: 720) end,
        fn cropped, src -> output([cropped, audio(src)], "square.mp4") end
      )

  Inputs can be a source, an input declaration, a list, a keyword list, or a map.
  The graph callback returns streams in the shape that the output callback
  receives as exports, or an explicit `%FFix.Graph{}`. The output callback may
  receive graph exports alone or graph exports and normalized inputs.
  """
  @spec command(
          Command.Input.source()
          | Command.Input.t()
          | [Command.Input.source() | Command.Input.t()]
          | keyword()
          | map(),
          function(),
          function() | keyword()
        ) :: Command.t()
  def command(inputs, callback, outputs_or_options),
    do: Build.command(inputs, callback, outputs_or_options)

  @doc group: "Command building"
  @doc """
  Builds a command with separate graph/output callbacks and command options.

      command(
        "input.mp4",
        fn src -> video(src) |> crop(w: 720, h: 720) end,
        fn cropped, src -> output([cropped, audio(src)], "square.mp4") end,
        global: [y: true, loglevel: :error]
      )

  The final options support `:global` only. Inputs, graph, and outputs are
  positional arguments, not option keys.
  """
  @spec command(
          Command.Input.source()
          | Command.Input.t()
          | [Command.Input.source() | Command.Input.t()]
          | keyword()
          | map(),
          function(),
          function(),
          keyword()
        ) :: Command.t()
  def command(inputs, graph_fun, outputs_fun, options),
    do: Build.command(inputs, graph_fun, outputs_fun, options)

  @doc group: "Serialization"
  @doc """
  Validates and serializes a graph to ffmpeg filtergraph syntax.
  """
  @spec to_filtergraph(Graph.t()) :: String.t()
  def to_filtergraph(%Graph{} = graph) do
    graph
    |> Builder.validate_graph!()
    |> FFix.Graph.Render.to_filtergraph()
  end

  @doc group: "Serialization"
  @doc """
  Serializes a command to the argv list that should be passed to an OS process.

      FFix.to_argv(command)
      #=> ["ffmpeg", "-i", "input.mp4", "-map", "0:v", "out.mp4"]
  """
  @spec to_argv(Command.t()) :: [String.t()]
  def to_argv(%Command{} = command), do: Command.to_argv(command)

  @doc group: "Serialization"
  @doc """
  Serializes a command as a shell-escaped string for logs and debugging.

  Prefer `to_argv/1` for execution.
  """
  @spec to_shell_string(Command.t()) :: String.t()
  def to_shell_string(%Command{} = command), do: Command.to_shell_string(command)

  @doc group: "Execution"
  @doc """
  Runs a command and returns `{:ok, result}` or `{:error, error}`.

  See `FFix.Runner` for stdout/stderr capture, progress events, and streaming
  execution options.
  """
  @spec run(Command.t() | nonempty_list(String.t()), [Runner.option()]) ::
          {:ok, Runner.Result.t()} | {:error, Runner.Error.t()}
  def run(command, options \\ []), do: Runner.run(command, options)

  @doc group: "Execution"
  @doc """
  Runs a command and returns the result, raising `FFix.Runner.Error` on failure.
  """
  @spec run!(Command.t() | nonempty_list(String.t()), [Runner.option()]) :: Runner.Result.t()
  def run!(command, options \\ []), do: Runner.run!(command, options)

  @doc group: "Execution"
  @doc """
  Runs a command as a lazy stream of execution events.

      FFix.stream(command, progress: true)
      |> Enum.each(fn
        {:progress, progress} -> IO.inspect(progress.status)
        {:exit, result} -> IO.inspect(result.exit_status)
        _event -> :ok
      end)
  """
  @spec stream(Command.t() | nonempty_list(String.t()), [Runner.option()]) :: term()
  def stream(command, options \\ []), do: Runner.stream(command, options)

  @doc group: "Execution"
  @doc """
  Runs a command as a lazy stream and raises on non-zero exit.
  """
  @spec stream!(Command.t() | nonempty_list(String.t()), [Runner.option()]) :: term()
  def stream!(command, options \\ []), do: Runner.stream!(command, options)

  @doc group: "Validation"
  @doc """
  Performs structural validation on a graph or command.

  Validation checks the model that `FFix` controls: declared inputs, graph refs,
  output sources, and filtered graph export mappings. It does not probe media
  files or execute ffmpeg.
  """
  @spec validate!(Graph.t() | Command.t()) :: Graph.t() | Command.t()
  def validate!(%Graph{} = graph), do: Builder.validate_graph!(graph)
  def validate!(%Command{} = command), do: Command.validate!(command)
end
