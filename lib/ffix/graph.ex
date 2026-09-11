defmodule FFix.Graph do
  @moduledoc """
  Reusable filtergraph data: nodes, exports, terminal sinks, and settings.

  Build ordinary filter pipelines directly from input declarations. Use a graph
  when you want to retain and reuse a whole pipeline as data:

      alias FFix.{Filter, Graph}
      port = Graph.input(:picture, :video)
      template = FFix.graph(outputs: [preview: Filter.scale(port, w: 320, h: -2)])
      source = FFix.input("input.mp4")
      instance = Graph.bind(template, picture: FFix.video(source))
      output = FFix.output(Filter.hflip(instance[:preview]), "out.mp4")
      command = FFix.command(output)

  Binding creates fresh identities for template filters. Supplied streams keep
  their identities: sharing a produced pad still requires `split`/`asplit`.
  Each exported reference carries the whole instance, including other branches,
  sinks, and settings. All produced pads must ultimately be consumed or mapped;
  unused branches do not disappear when only one export is selected.

  Local node numbers and wire labels are assigned when graphs are assembled.
  Logical export names and output mapping names are separate from wire labels.
  Graph access is read-only and returns filterable stream references. Parsing
  preserves explicit wire labels as export names, including names like `out0`.
  The supported graph-level setting is `sws_flags`; CLI controls belong on commands.
  """
  @moduledoc groups: ["Inputs", "Exports", "Parsing and serialization"]
  @behaviour Access

  alias __MODULE__.{Bind, Builder, Export, Parse, Render, StreamRef, Terminal}

  @type node_id :: pos_integer()
  @type setting :: {atom() | String.t(), term()}
  @type input_id :: non_neg_integer() | atom() | String.t() | reference()
  @type input_selector :: FFix.Command.Input.selector() | FFix.Command.Input.media() | :input
  @type t :: %__MODULE__{
          id: reference(),
          nodes: %{node_id() => term()},
          order: [node_id()],
          exports: [Export.t()],
          terminals: [node_id()],
          settings: [setting()]
        }

  defstruct id: nil, nodes: %{}, order: [], exports: [], terminals: [], settings: []

  @doc group: "Inputs"
  @doc """
  Declares an input port or an explicit positional FFmpeg input reference.

  Bind named ports before command construction. Positional references can also
  use the command's explicit ordered `inputs:` option. Selectors such as `:video`
  preserve FFmpeg's graph-input matching syntax; prefer `FFix.video/2` and
  `FFix.audio/2` for indexed selections from input declarations.
  """
  @spec input(input_id(), input_selector()) :: StreamRef.t()
  def input(input, selector), do: Builder.input(input, selector)

  @doc group: "Inputs"
  @doc "Builds an explicit input reference from syntax such as `\"0:v\"` or `\"1:s?\"`."
  @spec input_raw(String.t()) :: StreamRef.t()
  def input_raw(spec), do: Builder.input_raw(spec)

  @doc group: "Inputs"
  @doc """
  Instantiates a graph with explicit input bindings.

  Keys identify input IDs, or exact `{input_id, selector}` ports. Values are
  input declarations or selected streams. An input declaration can supply all
  selectors of a parsed input, for example `%{0 => source}`. Use exact port keys
  when replacing those selections independently with filtered streams.

  Captured inputs remain available when omitted from bindings; unbound ports and
  unused binding keys raise. Settings and terminal branches are retained, and
  incompatible settings fail when instances are composed. Explicit FFmpeg filter
  instance names are preserved, not renamed or rewritten inside command strings.
  """
  @spec bind(t(), map() | list()) :: t()
  def bind(%__MODULE__{} = graph, bindings), do: Bind.bind(graph, bindings)

  @doc group: "Exports"
  @doc "Returns filterable exports in declaration order, carrying the instance's other roots."
  @spec exports(t()) :: [StreamRef.t()]
  def exports(%__MODULE__{} = graph), do: graph |> Builder.graph_roots() |> elem(0)

  @doc group: "Exports"
  @doc "Returns terminal references, including their graph context, for command `terminals:`."
  @spec terminals(t()) :: [Terminal.t()]
  def terminals(%__MODULE__{} = graph), do: graph |> Builder.graph_roots() |> elem(1)

  @doc group: "Exports"
  @doc "Looks up an export by name or zero-based position; returns nil when missing."
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

    if index != nil and index < length(graph.exports), do: Enum.at(exports(graph), index)
  end

  @doc group: "Exports"
  @doc "Looks up an export by name or position, raising when missing."
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

  @doc group: "Parsing and serialization"
  @doc """
  Parses recorded filters into graph data without executing FFmpeg.

  The parser targets generated graphs and common FFmpeg syntax, not every
  hand-written form. Declare producers before consumers; forward references are
  rejected rather than guessed to be external selectors. Unknown filters or
  unresolved pad shapes require explicit construction with `FFix.Filter.filter/4`.

      graph = FFix.Graph.parse!("[0:v]scale=w=320:h=-1[preview]")
      FFix.to_filtergraph(graph)
      #=> "[0:v]scale=w=320:h=-1[preview];"
  """
  @spec parse!(String.t()) :: t()
  def parse!(source) when is_binary(source), do: Parse.parse!(source)

  @doc group: "Parsing and serialization"
  @doc "Validates every produced pad and serializes a graph to FFmpeg filtergraph syntax."
  @spec to_filtergraph(t()) :: String.t()
  def to_filtergraph(%__MODULE__{} = graph),
    do: graph |> Builder.validate_graph!() |> Render.to_filtergraph()
end
