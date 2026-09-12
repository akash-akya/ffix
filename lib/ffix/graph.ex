defmodule FFix.Graph do
  @moduledoc """
  Parse FFmpeg filtergraphs and reuse named filter pipelines.

  Ordinary pipelines can go straight from `FFix.Filter` to an output. Use a
  graph when you want to work with existing filtergraph text or package several
  filter operations behind named inputs and outputs.

  ## Start with an FFmpeg filtergraph

      alias FFix.Graph
      graph = Graph.parse!("[0:v]scale=w=640:h=-2[preview]")
      source = FFix.input("interview.mp4")
      bound = Graph.bind(graph, %{0 => source})

      FFix.output(bound[:preview], "preview.mp4") |> FFix.command()

  Binding associates the graph's input 0 with the input declaration. The name
  `preview` comes from the filtergraph's output label. `graph[:preview]` and
  `graph[0]` both retrieve that output as a stream you can filter or map.

  ## Build a reusable template

      alias FFix.{Filter, Graph}
      picture = Graph.input(:picture, :video)
      template = FFix.graph(outputs: [preview: Filter.scale(picture, w: 320, h: -2)])

      source = FFix.input("interview.mp4")
      instance = Graph.bind(template, picture: FFix.video(source, 0))
      flipped = Filter.hflip(instance[:preview])
      FFix.output(flipped, "preview.mp4") |> FFix.command()

  Each binding creates a separate instance of the template's filters. You can
  supply input declarations or streams that have already passed through filters.
  See `bind/2` for replacing individual input tracks.

  ## Keep branches connected

  Selecting one graph output keeps the other branches of that graph too.
  Connect every produced stream to another filter or an output. When branching
  a filtered stream, use `FFix.Filter.split/2` or `FFix.Filter.asplit/2`.

  Sinks finish a branch without writing its media to an output. Include them
  with `FFix.graph(terminals: [...])`, then pass `terminals(graph)` to the
  command's `terminals:` option. This also supports sink-only graphs.

  `FFix.graph/1` accepts the graph-level `sws_flags` setting. Equal settings
  compose; conflicting values raise an error. General CLI options belong on
  `FFix.command/2` or its inputs and outputs.

  See [FFmpeg filtergraph syntax](https://ffmpeg.org/ffmpeg-filters.html#Filtergraph-syntax)
  for labels, chains, and filter arguments.
  """
  @behaviour Access

  alias __MODULE__.{Bind, Builder, Export, Parse, Render, StreamRef, Terminal}

  @type node_id :: reference()
  @type setting :: {atom() | String.t(), term()}
  @type input_id :: non_neg_integer() | atom() | String.t() | reference()
  @type input_selector ::
          :input
          | FFix.Command.Input.media()
          | :video_only
          | {FFix.Command.Input.media() | :video_only, non_neg_integer()}
          | {:index, non_neg_integer()}
          | {:raw, String.t()}
  @type t :: %__MODULE__{
          id: reference(),
          nodes: %{node_id() => term()},
          order: [node_id()],
          exports: [Export.t()],
          terminals: [node_id()],
          settings: [setting()]
        }

  defstruct id: nil, nodes: %{}, order: [], exports: [], terminals: [], settings: []

  @doc """
  Declares a named graph input or a positional FFmpeg input reference.

      FFix.Graph.input(:picture, :video)
      FFix.Graph.input(0, {:audio, 1})

  Bind named inputs with `bind/2`. Positional inputs refer to the command's
  explicit `inputs:` order. Graph selectors such as `:video` supply one matching
  filter input. For selecting tracks from a declared file, use `FFix.video/3`
  or `FFix.audio/3` instead.
  """
  @spec input(input_id(), input_selector()) :: StreamRef.t()
  def input(input, selector), do: Builder.input(input, selector)

  @doc "Builds a graph input from an FFmpeg stream specifier such as `\"0:v\"`. It supplies one matching stream to a filter."
  @spec input_raw(String.t()) :: StreamRef.t()
  def input_raw(spec), do: Builder.input_raw(spec)

  @doc """
  Creates a graph instance by connecting its inputs to declarations or streams.

  Bindings are a map or ordered list of pairs. A key names an input or identifies
  one exact `{input, selector}`. An input declaration can supply all tracks of
  a graph input; a stream replaces one selected track:

      graph = FFix.Graph.parse!("[0:v:0]hflip[picture];[0:a:0]volume=0.5[sound]")
      source = FFix.input("interview.mp4")
      FFix.Graph.bind(graph, %{0 => source})

  To replace tracks independently, use keys such as `{0, {:video, 0}}` and
  `{0, {:audio, 0}}`. One stream cannot stand in for several different selectors;
  bind an input declaration or each exact track instead.

  Existing input declarations are retained when omitted. Unbound inputs, unused
  keys, overlapping bindings, and incompatible media raise `ArgumentError`.
  The instance retains supplied streams' other branches, sinks, and settings.
  Explicit FFmpeg filter instance names are preserved, so choose distinct names
  yourself when commands refer to particular filter instances.
  """
  @spec bind(t(), map() | list()) :: t()
  def bind(%__MODULE__{} = graph, bindings), do: Bind.bind(graph, bindings)

  @doc "Returns the graph's output streams in declaration order. Each stream retains the whole graph."
  @spec exports(t()) :: [StreamRef.t()]
  def exports(%__MODULE__{} = graph) do
    Enum.map(graph.exports, &stream(graph, &1))
  end

  @doc "Returns sink references for `FFix.command(outputs, terminals: Graph.terminals(graph))`."
  @spec terminals(t()) :: [Terminal.t()]
  def terminals(%__MODULE__{} = graph) do
    Enum.map(graph.terminals, fn node_id -> %Terminal{graph: graph, node_id: node_id} end)
  end

  @doc "Returns an output by name or zero-based position, or `nil` when missing. Also available as `graph[key]`."
  @spec export(t(), Export.name() | non_neg_integer()) :: StreamRef.t() | nil
  def export(%__MODULE__{} = graph, key) do
    index =
      cond do
        is_integer(key) and key >= 0 ->
          key

        (is_atom(key) and key not in [nil, true, false]) or is_binary(key) ->
          Enum.find_index(
            graph.exports,
            &(&1.name != nil and to_string(&1.name) == to_string(key))
          )

        true ->
          nil
      end

    if index != nil and index < length(graph.exports) do
      stream(graph, Enum.at(graph.exports, index))
    end
  end

  defp stream(%__MODULE__{id: graph_id} = graph, %Export{graph_id: graph_id} = export) do
    %StreamRef{graph: graph, ref: export.ref, media: export.media}
  end

  defp stream(_graph, _export) do
    raise ArgumentError, "graph export belongs to a different graph"
  end

  @doc "Like `export/2`, raising `ArgumentError` when the output is missing."
  @spec export!(t(), Export.name() | non_neg_integer()) :: StreamRef.t()
  def export!(%__MODULE__{} = graph, key) do
    export(graph, key) || raise ArgumentError, "unknown graph export: #{inspect(key)}"
  end

  @doc false
  def fetch(%__MODULE__{} = graph, key) do
    case export(graph, key) do
      nil -> :error
      stream -> {:ok, stream}
    end
  end

  @doc false
  def get_and_update(%__MODULE__{}, _key, _fun),
    do: raise(ArgumentError, "FFix.Graph access is read-only")

  @doc false
  def pop(%__MODULE__{}, _key), do: raise(ArgumentError, "FFix.Graph access is read-only")

  @doc false
  @spec nodes(t()) :: [term()]
  def nodes(%__MODULE__{nodes: nodes, order: order}), do: Enum.map(order, &Map.fetch!(nodes, &1))

  @doc false
  @spec update_node(t(), node_id(), (term() -> term())) :: t()
  def update_node(%__MODULE__{nodes: nodes} = graph, node_id, fun),
    do: %{graph | nodes: Map.update!(nodes, node_id, fun)}

  @doc """
  Parses FFmpeg filtergraph text into a graph with named output streams.

      graph = FFix.Graph.parse!("[0:v]scale=w=320:h=-2[preview]")
      FFix.to_filtergraph(graph)
      #=> "[0:v]scale=w=320:h=-2[preview];"

  Filters must be known to the helper catalog and have a resolvable output
  layout. Declare each labeled producer before the filters that consume it;
  forward references and cycles raise `ArgumentError`. The parser supports
  common FFmpeg syntax, including quoted and escaped option values.

  Use `FFix.Filter.filter/4` to construct filters with other names or explicit
  output layouts. Bind parsed inputs with `bind/2` before normal command assembly,
  or provide an explicit `inputs:` list to `FFix.command/2`.
  """
  @spec parse!(String.t()) :: t()
  def parse!(source) when is_binary(source), do: Parse.parse!(source)

  @doc """
  Validates connections and returns FFmpeg filtergraph text.

  Standalone rendering uses positional input references. For graphs bound to
  input declarations, use `FFix.to_argv/1` on the command so input positions
  can be resolved. Logical graph names may be escaped or replaced with safe
  labels in the rendered text.
  """
  @spec to_filtergraph(t()) :: String.t()
  def to_filtergraph(%__MODULE__{} = graph),
    do: graph |> Builder.validate_graph!() |> Render.to_filtergraph()
end
