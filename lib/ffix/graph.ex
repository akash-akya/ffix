defmodule FFix.Graph do
  @moduledoc """
  Filtergraph data model.

  A graph is a pure Elixir value containing input references, filter nodes,
  exported streams, terminal sinks, and graph-level settings. It is serialized
  to ffmpeg syntax only at `FFix.to_filtergraph/1`, `FFix.to_argv/1`, or `FFix.run/1`.

  Most users build filter pipelines inside `FFix.command/3` callbacks:

      FFix.command(
        "input.mp4",
        fn src ->
          src[:video] |> FFix.Filter.scale(w: 1280, h: -1)
        end,
        fn video, src ->
          FFix.output([video, src[:audio]], "out.mp4")
        end
      )

  Use `input/2` when building a reusable graph outside a command callback:

      video = FFix.Graph.input(0, :video)

      graph =
        FFix.graph(
          outputs: [
            preview: video |> FFix.Filter.scale(w: 320, h: -1)
          ]
        )

  `graph[:name]` and `graph[index]` return exported streams from a `%FFix.Graph{}`
  value. In `FFix.command/3`, callback input and graph output shapes are preserved,
  so use normal Elixir access for the shape you return.

  ## Selectors

    * `:input` maps the whole input, like `-map 0`
    * `:video` maps/selects the video stream class, like `0:v`
    * `:audio` maps/selects the audio stream class, like `0:a`
    * `{:video, 1}` or `{:audio, 1}` selects a stream-class index
    * `{:raw, "s?"}` keeps an ffmpeg selector escape hatch
  """
  @moduledoc groups: [
               "Inputs",
               "Exports",
               "Parsing and serialization"
             ]

  @behaviour Access

  alias __MODULE__.Builder
  alias __MODULE__.Export
  alias __MODULE__.Parse
  alias __MODULE__.Render
  alias __MODULE__.StreamRef

  @type node_id :: pos_integer()
  @type setting :: {atom() | String.t(), term()}
  @type input_id :: non_neg_integer() | atom() | String.t() | reference()
  @type input_selector ::
          :input
          | :video
          | :audio
          | {:video, non_neg_integer()}
          | {:audio, non_neg_integer()}
          | {:raw, String.t()}

  @type t :: %__MODULE__{
          id: reference(),
          nodes: %{node_id() => term()},
          order: [node_id()],
          exports: [Export.t()],
          terminals: [node_id()],
          settings: [setting()]
        }

  defstruct id: nil,
            nodes: %{},
            order: [],
            exports: [],
            terminals: [],
            settings: []

  @doc group: "Inputs"
  @doc """
  Builds a stream reference for an ffmpeg command input.

  Use this outside command callbacks, where callback input values are not
  available. Inside `FFix.command/3`, prefer the input value you received, such as
  `src[:video]` or `inputs[:src][:video]`.

  ## Examples

      video = FFix.Graph.input(0, :video)
      audio = FFix.Graph.input(0, :audio)

      graph =
        FFix.graph(
          outputs: [
            main: video |> FFix.Filter.scale(w: 1280, h: -1)
          ]
        )

      FFix.Command.new(
        inputs: [FFix.input("input.mp4")],
        graph: graph,
        outputs: [FFix.Command.output([graph[:main], audio], "out.mp4")]
      )
  """
  @spec input(input_id(), input_selector()) :: StreamRef.t()
  def input(input, selector), do: Builder.input(input, selector)

  @doc group: "Inputs"
  @doc """
  Builds a stream reference from a raw ffmpeg input selector.

  This is an escape hatch for selectors that do not have a structured form yet.
  It currently expects an indexed selector such as `"0:v"` or `"1:s?"`.
  """
  @spec input_raw(String.t()) :: StreamRef.t()
  def input_raw(spec), do: Builder.input_raw(spec)

  @doc group: "Exports"
  @doc """
  Returns graph exports in declaration order.
  """
  @spec exports(t()) :: [Export.t()]
  def exports(%__MODULE__{exports: exports}), do: exports

  @doc group: "Exports"
  @doc """
  Looks up a graph export by name or zero-based position.

  Returns `nil` when the export does not exist.
  """
  @spec export(t(), Export.name() | non_neg_integer()) :: Export.t() | nil
  def export(%__MODULE__{exports: exports}, name) when is_atom(name) or is_binary(name) do
    key = export_name_key(name)
    Enum.find(exports, &(export_name_key(&1.name) == key))
  end

  def export(%__MODULE__{exports: exports}, index) when is_integer(index) and index >= 0 do
    Enum.at(exports, index)
  end

  @doc group: "Exports"
  @doc """
  Looks up a graph export by name or position, raising when it is missing.
  """
  @spec export!(t(), Export.name() | non_neg_integer()) :: Export.t()
  def export!(%__MODULE__{} = graph, key) do
    case export(graph, key) do
      nil -> raise ArgumentError, "unknown graph export: #{inspect(key)}"
      export -> export
    end
  end

  @doc false
  @spec fetch(t(), Export.name() | non_neg_integer()) :: {:ok, Export.t()} | :error
  def fetch(%__MODULE__{} = graph, key)
      when is_atom(key) or is_binary(key) or (is_integer(key) and key >= 0) do
    case export(graph, key) do
      nil -> :error
      export -> {:ok, export}
    end
  end

  def fetch(%__MODULE__{}, _key), do: :error

  @doc false
  def get_and_update(%__MODULE__{}, _key, _fun) do
    raise ArgumentError, "FFix.Graph access is read-only"
  end

  @doc false
  def pop(%__MODULE__{}, _key) do
    raise ArgumentError, "FFix.Graph access is read-only"
  end

  @doc false
  @spec nodes(t()) :: [term()]
  def nodes(%__MODULE__{nodes: nodes, order: order}) do
    Enum.map(order, &Map.fetch!(nodes, &1))
  end

  @doc false
  @spec update_node(t(), node_id(), (term() -> term())) :: t()
  def update_node(%__MODULE__{nodes: nodes} = graph, node_id, fun) do
    %{graph | nodes: Map.update!(nodes, node_id, fun)}
  end

  @doc group: "Parsing and serialization"
  @doc """
  Parses a filtergraph string into `%FFix.Graph{}`.

  The parser is pragmatic: it targets graphs produced by `FFix` and common
  ffmpeg filtergraph syntax. It is not meant to accept every hand-written
  filtergraph form. Declare producers before consumers; forward references
  are rejected rather than guessed to be external input selectors.

  ## Examples

      graph = FFix.Graph.parse!("[0:v]scale=w=320:h=-1[preview]")
      FFix.to_filtergraph(graph)
      #=> "[0:v]scale=w=320:h=-1[preview];"
  """
  @spec parse!(String.t()) :: t()
  def parse!(source) when is_binary(source), do: Parse.parse!(source)

  @doc group: "Parsing and serialization"
  @doc """
  Validates and serializes a graph to ffmpeg filtergraph syntax.
  """
  @spec to_filtergraph(t()) :: String.t()
  def to_filtergraph(%__MODULE__{} = graph),
    do: graph |> Builder.validate_graph!() |> Render.to_filtergraph()

  defp export_name_key(nil), do: nil
  defp export_name_key(name) when is_atom(name) or is_binary(name), do: to_string(name)
end
