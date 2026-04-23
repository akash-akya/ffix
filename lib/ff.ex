defmodule FF do
  @moduledoc """
  Public entry point for building ffmpeg filtergraphs and commands.

  `FF` keeps graph construction, command construction, and execution as separate
  data-first steps:

    * `input/1,2` declares command inputs.
    * `graph/1` builds a `%FF.Graph{}` from streams.
    * `output/2,3` declares command outputs and stream mappings.
    * `command/1` assembles those pieces into a `%FF.Command{}`.
    * `to_argv/1` serializes the command to the exact argv passed to ffmpeg.

  `use FF` only imports these functions plus generated filter helpers. It does
  not introduce a separate command DSL.

  The high-level `command/1` API accepts callback functions for the graph and
  outputs:

      command(
        inputs: [
          src: input("input.mp4")
        ],
        graph: fn inputs ->
          [
            preview: inputs.src[:video] |> scale(w: 320, h: -1)
          ]
        end,
        outputs: fn graph, %{inputs: inputs} ->
          output("preview.mp4",
            video: graph.preview,
            audio: inputs.src[:audio],
            vcodec: :libx264,
            acodec: :aac
          )
        end
      )

  A graph callback receives the named command inputs and may return:

    * a `%FF.Graph{}`
    * a keyword list of graph exports, such as `[preview: stream]`
    * `nil` when the command does not need a filtergraph

  An outputs callback can accept either one or two arguments. A one-argument
  callback receives the graph export map directly. A two-argument callback
  receives the graph export map plus a context map currently shaped as
  `%{inputs: inputs}`.
  """

  alias FF.Command
  alias FF.Expr
  alias FF.Command.Build
  alias FF.Filter.Builder
  alias FF.Graph
  alias FF.Runner
  alias FF.Stream
  alias FF.Terminal

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
          output: 3,
          shape: 2
        ]

      import FF.Filter
    end
  end

  @spec input(Command.Input.source()) :: Command.Input.t()
  def input(source), do: Command.input(source)

  @spec input(Command.Input.source(), keyword()) :: Command.Input.t()
  def input(source, options) when is_list(options), do: Command.input(source, options)

  @spec expr(String.t()) :: Expr.t()
  def expr(source) when is_binary(source), do: %Expr{source: source}

  @spec filter(atom() | String.t(), [Stream.t()], keyword()) ::
          Stream.t() | Terminal.t() | [Stream.t()] | tuple()
  def filter(name, inputs, options \\ []) when is_list(inputs) do
    Builder.filter(name, inputs, options)
  end

  @spec shape(Stream.t() | [Stream.t()] | tuple(), [FF.Filter.Builder.output_media()]) ::
          Stream.t() | [Stream.t()]
  def shape(result, outputs), do: Builder.shape(result, outputs)

  @spec graph(keyword()) :: Graph.t()
  def graph(options), do: Builder.graph(options)

  @spec output(Command.Output.target(), keyword()) :: Command.Output.t()
  def output(target, options_or_sources), do: Build.output(target, options_or_sources)

  @spec output(Command.Output.target(), Command.source() | [Command.source()], keyword()) ::
          Command.Output.t()
  def output(target, sources, options), do: Command.output(target, sources, options)

  @spec command() :: Command.t()
  def command, do: Command.new()

  @spec command(keyword()) :: Command.t()
  def command(options) when is_list(options), do: Build.command(options)

  @spec to_filtergraph(Graph.t()) :: String.t()
  def to_filtergraph(%Graph{} = graph) do
    graph
    |> Builder.validate_graph!()
    |> FF.Graph.Render.to_filtergraph()
  end

  @spec to_argv(Command.t()) :: [String.t()]
  def to_argv(%Command{} = command), do: Command.to_argv(command)

  @spec to_shell_string(Command.t()) :: String.t()
  def to_shell_string(%Command{} = command), do: Command.to_shell_string(command)

  @spec run(Command.t() | nonempty_list(String.t()), [Runner.option()]) ::
          {:ok, Runner.Result.t()} | {:error, Runner.Error.t()}
  def run(command, options \\ []), do: Runner.run(command, options)

  @spec run!(Command.t() | nonempty_list(String.t()), [Runner.option()]) :: Runner.Result.t()
  def run!(command, options \\ []), do: Runner.run!(command, options)

  @spec stream(Command.t() | nonempty_list(String.t()), [Runner.option()]) :: term()
  def stream(command, options \\ []), do: Runner.stream(command, options)

  @spec stream!(Command.t() | nonempty_list(String.t()), [Runner.option()]) :: term()
  def stream!(command, options \\ []), do: Runner.stream!(command, options)

  @spec validate!(Graph.t() | Command.t()) :: Graph.t() | Command.t()
  def validate!(%Graph{} = graph), do: Builder.validate_graph!(graph)
  def validate!(%Command{} = command), do: Command.validate!(command)
end
