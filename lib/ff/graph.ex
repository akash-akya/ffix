defmodule FF.Graph do
  @moduledoc """
  Canonical representation of a complete filtergraph.
  """

  @behaviour Access

  alias __MODULE__.Export
  alias __MODULE__.Node
  alias __MODULE__.Parse
  alias __MODULE__.Render
  alias __MODULE__.InputRef
  alias FF.Filter.Builder

  @type node_id :: pos_integer()
  @type setting :: {atom() | String.t(), term()}
  @type input_id :: InputRef.input_id() | atom()
  @type input_selector :: InputRef.selector()

  @type t :: %__MODULE__{
          nodes: %{node_id() => Node.t()},
          order: [node_id()],
          exports: [Export.t()],
          terminals: [node_id()],
          settings: [setting()]
        }

  defstruct nodes: %{},
            order: [],
            exports: [],
            terminals: [],
            settings: []

  @spec input(input_id(), input_selector()) :: FF.Stream.t()
  def input(input, selector), do: Builder.input(input, selector)

  @spec input_raw(String.t()) :: FF.Stream.t()
  def input_raw(spec), do: Builder.input_raw(spec)

  @spec exports(t()) :: [Export.t()]
  def exports(%__MODULE__{exports: exports}), do: exports

  @spec export(t(), Export.name() | non_neg_integer()) :: Export.t() | nil
  def export(%__MODULE__{exports: exports}, name) when is_atom(name) or is_binary(name) do
    key = export_name_key(name)
    Enum.find(exports, &(export_name_key(&1.name) == key))
  end

  def export(%__MODULE__{exports: exports}, index) when is_integer(index) and index >= 0 do
    Enum.at(exports, index)
  end

  @spec export!(t(), Export.name() | non_neg_integer()) :: Export.t()
  def export!(%__MODULE__{} = graph, key) do
    case export(graph, key) do
      nil -> raise ArgumentError, "unknown graph export: #{inspect(key)}"
      export -> export
    end
  end

  @spec fetch(t(), Export.name() | non_neg_integer()) :: {:ok, Export.t()} | :error
  def fetch(%__MODULE__{} = graph, key)
      when is_atom(key) or is_binary(key) or (is_integer(key) and key >= 0) do
    case export(graph, key) do
      nil -> :error
      export -> {:ok, export}
    end
  end

  def fetch(%__MODULE__{}, _key), do: :error

  def get_and_update(%__MODULE__{}, _key, _fun) do
    raise ArgumentError, "FF.Graph access is read-only"
  end

  def pop(%__MODULE__{}, _key) do
    raise ArgumentError, "FF.Graph access is read-only"
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

  @spec rename_export(t(), Export.name(), Export.name()) :: t()
  def rename_export(%__MODULE__{exports: exports} = graph, old_name, new_name) do
    old_name = export_name_key(old_name)

    exports =
      Enum.map(exports, fn
        %Export{name: name} = export ->
          if export_name_key(name) == old_name do
            %{export | name: new_name}
          else
            export
          end
      end)

    %{graph | exports: exports}
  end

  @spec parse!(String.t()) :: t()
  def parse!(source) when is_binary(source), do: Parse.parse!(source)

  @spec to_filtergraph(t()) :: String.t()
  def to_filtergraph(%__MODULE__{} = graph), do: Render.to_filtergraph(graph)

  defp export_name_key(nil), do: nil
  defp export_name_key(name) when is_atom(name) or is_binary(name), do: to_string(name)
end
