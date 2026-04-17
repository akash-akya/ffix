defmodule FF do
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
          shape: 2,
          stream_ref: 2
        ]

      import FF.Filter
    end
  end

  @type input_id :: FF.Graph.InputRef.input_id() | atom()
  @type input_selector :: FF.Graph.InputRef.selector()

  @spec input(Command.Input.source()) :: Command.Input.t()
  def input(source), do: Command.input(source)

  @spec input(Command.Input.source(), keyword()) :: Command.Input.t()
  def input(source, options) when is_list(options), do: Command.input(source, options)

  @spec stream_ref(input_id(), input_selector()) :: Stream.t()
  def stream_ref(input, selector), do: Builder.input(input, selector)

  @spec stream_ref_raw(String.t()) :: Stream.t()
  def stream_ref_raw(spec), do: Builder.input_raw(spec)

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

  @spec output(Command.Output.target(), keyword() | Command.source() | [Command.source()]) ::
          Command.Output.t()
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
