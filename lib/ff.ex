defmodule FF do
  alias FF.Expr
  alias FF.Filter.Builder
  alias FF.Graph
  alias FF.Stream
  alias FF.Terminal

  @type input_selector :: FF.Graph.InputRef.selector()

  @spec input(non_neg_integer(), input_selector()) :: Stream.t()
  def input(index, selector), do: Builder.input(index, selector)

  @spec input_raw(String.t()) :: Stream.t()
  def input_raw(spec), do: Builder.input_raw(spec)

  @spec expr(String.t()) :: Expr.t()
  def expr(source) when is_binary(source), do: %Expr{source: source}

  @spec filter(atom() | String.t(), [Stream.t()], keyword()) ::
          Stream.t() | Terminal.t() | [Stream.t()] | tuple()
  def filter(name, inputs, options \\ []) when is_list(inputs) do
    Builder.filter(name, inputs, options)
  end

  @spec graph(keyword()) :: Graph.t()
  def graph(options), do: Builder.graph(options)

  @spec to_filtergraph(Graph.t()) :: String.t()
  def to_filtergraph(%Graph{} = graph) do
    graph
    |> Builder.validate_graph!()
    |> FF.Graph.Render.to_filtergraph()
  end

  @spec validate!(Graph.t()) :: Graph.t()
  def validate!(%Graph{} = graph), do: Builder.validate_graph!(graph)
end
