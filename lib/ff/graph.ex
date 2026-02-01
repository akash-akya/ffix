defmodule FF.Graph do
  @moduledoc """
  Canonical representation of a complete filtergraph.
  """

  alias __MODULE__.Export
  alias __MODULE__.Node
  alias __MODULE__.Parse
  alias __MODULE__.Render

  @type node_id :: pos_integer()
  @type setting :: {atom() | String.t(), term()}

  @type t :: %__MODULE__{
          version: pos_integer(),
          nodes: %{node_id() => Node.t()},
          order: [node_id()],
          exports: [Export.t()],
          terminals: [node_id()],
          settings: [setting()],
          metadata: map()
        }

  defstruct version: 1,
            nodes: %{},
            order: [],
            exports: [],
            terminals: [],
            settings: [],
            metadata: %{}

  @spec exports(t()) :: [Export.t()]
  def exports(%__MODULE__{exports: exports}), do: exports

  @spec export(t(), atom() | non_neg_integer()) :: Export.t() | nil
  def export(%__MODULE__{exports: exports}, name) when is_atom(name) do
    Enum.find(exports, &(&1.name == name))
  end

  def export(%__MODULE__{exports: exports}, index) when is_integer(index) and index >= 0 do
    Enum.at(exports, index)
  end

  @spec export!(t(), atom() | non_neg_integer()) :: Export.t()
  def export!(%__MODULE__{} = graph, key) do
    case export(graph, key) do
      nil -> raise ArgumentError, "unknown graph export: #{inspect(key)}"
      export -> export
    end
  end

  @spec nodes(t()) :: [Node.t()]
  def nodes(%__MODULE__{nodes: nodes, order: order}) do
    Enum.map(order, &Map.fetch!(nodes, &1))
  end

  @spec update_node(t(), node_id(), (Node.t() -> Node.t())) :: t()
  def update_node(%__MODULE__{nodes: nodes} = graph, node_id, fun) do
    %{graph | nodes: Map.update!(nodes, node_id, fun)}
  end

  @spec put_setting(t(), atom() | String.t(), term()) :: t()
  def put_setting(%__MODULE__{settings: settings} = graph, key, value) do
    %{graph | settings: settings ++ [{key, value}]}
  end

  @spec rename_export(t(), atom(), atom()) :: t()
  def rename_export(%__MODULE__{exports: exports} = graph, old_name, new_name) do
    exports =
      Enum.map(exports, fn
        %Export{name: ^old_name} = export -> %{export | name: new_name}
        export -> export
      end)

    %{graph | exports: exports}
  end

  @spec parse!(String.t()) :: t()
  def parse!(source) when is_binary(source), do: Parse.parse!(source)

  @spec to_filtergraph(t()) :: String.t()
  def to_filtergraph(%__MODULE__{} = graph), do: Render.to_filtergraph(graph)
end
