defmodule FF do
  @moduledoc """
  Public entry point for building ffmpeg filtergraphs and commands.

  `FF` keeps the workflow data-first:

    * declare inputs with `input/1` or `input/2`
    * build streams with generated `FF.Filter` helpers
    * export graph streams with `graph/1`
    * map streams to outputs with `output/2`
    * serialize with `to_argv/1` or execute with `run/2`

  `use FF` imports the top-level helpers plus generated filter functions. It
  does not introduce a separate DSL; callbacks receive and return ordinary
  Elixir values.

  ## Command Callbacks

  `command/1` is the high-level API. The graph callback receives named inputs.
  The output callback receives graph exports and, when requested, command
  context:

      command(
        inputs: [src: input("input.mp4")],
        graph: fn inputs ->
          [
            main: inputs.src[:video] |> scale(w: 1280, h: -1)
          ]
        end,
        outputs: fn graph, %{inputs: inputs} ->
          output("out.mp4",
            video: graph.main,
            audio: inputs.src[:audio],
            "c:v": :libx264,
            "c:a": :aac
          )
        end
      )

  A graph callback may return:

    * a `%FF.Graph{}`
    * a keyword list of graph exports, such as `[preview: stream]`
    * `nil` when the command does not need a filtergraph

  An outputs callback may accept one or two arguments. A one-argument callback
  receives graph exports directly. A two-argument callback also receives a
  context map, currently `%{inputs: inputs}`.

  ## Output Mapping

  Use `video:` and `audio:` for common mappings:

      output("out.mp4", video: graph.main, audio: inputs.src[:audio])

  Use `sources:` when `-map` ordering matters:

      output("archive.mkv",
        sources: [graph.main, inputs.src[audio: 1], inputs.src[audio: 0]]
      )

  Output options are intentionally ffmpeg-shaped. Keys are rendered as CLI
  option names, so stream-specific options can use quoted atoms or strings such
  as `"c:v"` and `"metadata:s:a:0"`.

  ## Boundaries

  `validate!/1` performs structural checks only. It does not probe media files
  or ask ffmpeg to validate the command.

  `to_argv/1` is the canonical serialization boundary. `to_shell_string/1` is
  useful for logs, but argv should be preferred when executing.
  """

  alias FF.Command
  alias FF.Expr
  alias FF.Command.Build
  alias FF.Filter.Builder
  alias FF.Graph
  alias FF.Runner
  alias FF.Stream
  alias FF.Terminal

  @doc """
  Imports the high-level `FF` helpers and generated filter functions.

      defmodule Pipeline do
        use FF

        def resize(video) do
          video |> scale(w: 1280, h: -1)
        end
      end
  """
  defmacro __using__(_options) do
    quote do
      import FF,
        only: [
          command: 1,
          expr: 1,
          graph: 1,
          input: 1,
          input: 2,
          output: 2,
          shape: 2
        ]

      import FF.Filter
    end
  end

  @doc """
  Declares an ffmpeg input without input options.

  This returns an `%FF.Command.Input{}`. In `command/1`, inputs are normally
  named in a keyword list:

      command(
        inputs: [src: input("input.mp4")],
        outputs: fn _graph, %{inputs: inputs} ->
          output("copy.mp4", video: inputs.src[:video], "c:v": :copy)
        end
      )

  For an optionless file input, `command/1` also accepts the shortcut
  `inputs: [src: "input.mp4"]`.
  """
  @spec input(Command.Input.source()) :: Command.Input.t()
  def input(source), do: Command.input(source)

  @doc """
  Declares an ffmpeg input with input options.

  Options are rendered before `-i`.

      input("clip.mp4", ss: "00:00:05", t: "00:00:10")
      input(:stdin, f: :wav)

  Option keys are ffmpeg CLI option names without the leading dash.
  """
  @spec input(Command.Input.source(), keyword()) :: Command.Input.t()
  def input(source, options) when is_list(options), do: Command.input(source, options)

  @doc """
  Wraps a raw ffmpeg expression so it is serialized as an expression value.

      drawtext(video, text: "Hello", x: expr("w-tw-20"), y: 20)
  """
  @spec expr(String.t()) :: Expr.t()
  def expr(source) when is_binary(source), do: %Expr{source: source}

  @doc """
  Applies a filter by name.

  Most code should call generated helpers from `FF.Filter`, such as
  `scale/2`, `overlay/3`, or `fps/2`. Use `filter/3` when the filter name is
  dynamic.

      FF.filter(:scale, [video], w: 1280, h: -1)
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

  @doc """
  Assigns a concrete output shape to a dynamic or ambiguous filter result.

  Some ffmpeg filters have output counts or media types that depend on options.
  `shape/2` lets you state the result explicitly before exporting or mapping it.

      [audio, video] =
        input_audio
        |> ebur128(video: true)
        |> FF.shape([:audio, :video])
  """
  @spec shape(Stream.t() | [Stream.t()] | tuple(), [output_media()]) ::
          Stream.t() | [Stream.t()]
  def shape(result, outputs), do: Builder.shape(result, outputs)

  @doc """
  Builds a `%FF.Graph{}` from exported streams and terminal sinks.

  Common options:

    * `:output` - a single unnamed exported stream
    * `:outputs` - a list of named or unnamed exported streams
    * `:terminals` - sink-ending filter results, such as `nullsink`
    * `:settings` - graph-level settings such as `sws_flags`

  In `command/1`, graph callbacks can return a keyword list of exports directly.
  Use `graph/1` when you need terminals or settings.

      FF.graph(
        outputs: [main: video |> scale(w: 1280, h: -1)],
        settings: [sws_flags: [:accurate_rnd]]
      )
  """
  @spec graph(keyword()) :: Graph.t()
  def graph(options), do: Builder.graph(options)

  @doc """
  Declares an output target and stream mappings.

  Use `video:` and `audio:` for common cases:

      output("out.mp4",
        video: graph.main,
        audio: inputs.src[:audio],
        "c:v": :libx264,
        "c:a": :aac
      )

  Use `sources:` when exact `-map` order matters:

      output("archive.mkv",
        sources: [graph.main, inputs.src[audio: 1], inputs.src[audio: 0]],
        c: :copy
      )

  Remaining options are rendered as ffmpeg output options after all `-map`
  entries and before the output target.
  """
  @spec output(Command.Output.target(), keyword()) :: Command.Output.t()
  def output(target, options_or_sources), do: Build.output(target, options_or_sources)

  @doc """
  Returns an empty low-level `%FF.Command{}`.

  Prefer `command/1` for the callback API.
  """
  @spec command() :: Command.t()
  def command, do: Command.new()

  @doc """
  Builds a command from high-level command options.

  Supported top-level keys:

    * `:global` - ffmpeg global options
    * `:inputs` - keyword list of named inputs
    * `:graph` - a `%FF.Graph{}` or one-argument callback
    * `:outputs` - output value, list, or callback

  Graph callbacks receive the input map. Output callbacks can receive either
  graph exports, or graph exports plus `%{inputs: inputs}`.

      command(
        global: [y: true],
        inputs: [src: input("input.mp4")],
        graph: fn inputs ->
          [main: inputs.src[:video] |> scale(w: 1280, h: -1)]
        end,
        outputs: fn graph, %{inputs: inputs} ->
          output("out.mp4", video: graph.main, audio: inputs.src[:audio])
        end
      )
  """
  @spec command(keyword()) :: Command.t()
  def command(options) when is_list(options), do: Build.command(options)

  @doc """
  Validates and serializes a graph to ffmpeg filtergraph syntax.
  """
  @spec to_filtergraph(Graph.t()) :: String.t()
  def to_filtergraph(%Graph{} = graph) do
    graph
    |> Builder.validate_graph!()
    |> FF.Graph.Render.to_filtergraph()
  end

  @doc """
  Serializes a command to the argv list that should be passed to an OS process.

      FF.to_argv(command)
      #=> ["ffmpeg", "-i", "input.mp4", "-map", "0:v", "out.mp4"]
  """
  @spec to_argv(Command.t()) :: [String.t()]
  def to_argv(%Command{} = command), do: Command.to_argv(command)

  @doc """
  Serializes a command as a shell-escaped string for logs and debugging.

  Prefer `to_argv/1` for execution.
  """
  @spec to_shell_string(Command.t()) :: String.t()
  def to_shell_string(%Command{} = command), do: Command.to_shell_string(command)

  @doc """
  Runs a command and returns `{:ok, result}` or `{:error, error}`.

  See `FF.Runner` for stdout/stderr capture, progress events, and streaming
  execution options.
  """
  @spec run(Command.t() | nonempty_list(String.t()), [Runner.option()]) ::
          {:ok, Runner.Result.t()} | {:error, Runner.Error.t()}
  def run(command, options \\ []), do: Runner.run(command, options)

  @doc """
  Runs a command and returns the result, raising `FF.Runner.Error` on failure.
  """
  @spec run!(Command.t() | nonempty_list(String.t()), [Runner.option()]) :: Runner.Result.t()
  def run!(command, options \\ []), do: Runner.run!(command, options)

  @doc """
  Runs a command as a lazy stream of execution events.

      FF.stream(command, progress: true)
      |> Enum.each(fn
        {:progress, progress} -> IO.inspect(progress.status)
        {:exit, result} -> IO.inspect(result.exit_status)
        _event -> :ok
      end)
  """
  @spec stream(Command.t() | nonempty_list(String.t()), [Runner.option()]) :: term()
  def stream(command, options \\ []), do: Runner.stream(command, options)

  @doc """
  Runs a command as a lazy stream and raises on non-zero exit.
  """
  @spec stream!(Command.t() | nonempty_list(String.t()), [Runner.option()]) :: term()
  def stream!(command, options \\ []), do: Runner.stream!(command, options)

  @doc """
  Performs structural validation on a graph or command.

  Validation checks the model that `FF` controls: declared inputs, graph refs,
  output sources, and filtered graph export mappings. It does not probe media
  files or execute ffmpeg.
  """
  @spec validate!(Graph.t() | Command.t()) :: Graph.t() | Command.t()
  def validate!(%Graph{} = graph), do: Builder.validate_graph!(graph)
  def validate!(%Command{} = command), do: Command.validate!(command)
end
