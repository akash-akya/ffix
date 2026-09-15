defmodule FFix.Graph.Validator do
  @moduledoc false

  alias FFix.Filter.Shape
  alias FFix.Graph
  alias FFix.Graph.{Export, InputRef, Node, Ref}
  alias FFix.Metadata

  @spec graph!(Graph.t(), keyword()) :: Graph.t()
  def graph!(%Graph{} = graph, options \\ []) do
    unless is_reference(graph.id) and is_map(graph.nodes) and is_list(graph.order) and
             is_list(graph.exports) and is_list(graph.terminals) do
      raise ArgumentError, "invalid graph structure"
    end

    unless length(graph.order) == map_size(graph.nodes) and
             MapSet.new(graph.order) == MapSet.new(Map.keys(graph.nodes)) do
      raise ArgumentError, "graph order must contain every node exactly once"
    end

    settings!(graph.settings)

    Enum.reduce(graph.order, %{}, fn node_id, preceding ->
      node = Map.fetch!(graph.nodes, node_id)
      validate_node!(node, node_id)
      Enum.each(node.inputs, &validate_ref!(&1, preceding, "input"))
      validate_node_inputs!(node, preceding)
      Map.put(preceding, node_id, node)
    end)

    Enum.reduce(graph.exports, MapSet.new(), fn export, names ->
      unless match?(%Export{graph_id: graph_id} when graph_id == graph.id, export) do
        raise ArgumentError, "graph export belongs to a different graph"
      end

      node = validate_ref!(export.ref, graph.nodes, "export")

      unless export.media == Enum.at(node.output_media, export.ref.output) do
        raise ArgumentError, "graph export media does not match its output pad"
      end

      key =
        case export.name do
          nil -> nil
          name when is_atom(name) and name not in [true, false] -> Atom.to_string(name)
          name when is_binary(name) and name != "" -> name
          name -> raise ArgumentError, "invalid graph export name: #{inspect(name)}"
        end

      if key != nil and MapSet.member?(names, key) do
        raise ArgumentError, "duplicate graph export name: #{inspect(export.name)}"
      end

      MapSet.put(names, key)
    end)

    sinks = Enum.filter(graph.order, &Node.sink?(graph.nodes[&1]))

    unless length(sinks) == length(graph.terminals) and
             MapSet.new(sinks) == MapSet.new(graph.terminals) do
      raise ArgumentError, "graph terminals must contain every sink exactly once"
    end

    validate_connected_outputs!(graph, Keyword.get(options, :allow_unused, false))
    graph
  end

  defp validate_node!(%Node{id: node_id} = node, node_id)
       when is_reference(node_id) do
    unless node.kind in [:input, :filter] and is_list(node.inputs) and is_list(node.output_media) do
      raise ArgumentError, "invalid output shape for graph node #{inspect(node_id)}"
    end

    if node.kind == :input do
      unless node.inputs == [] and is_struct(node.input_ref, InputRef) do
        raise ArgumentError, "invalid graph input node #{inspect(node_id)}"
      end

      InputRef.normalize_input_id!(node.input_ref.input)
      selector = selector!(node.input_ref.selector)

      unless node.output_media == [InputRef.media(selector)] do
        raise ArgumentError, "graph input media does not match its selector"
      end
    else
      Enum.each(node.output_media, &media!/1)
      filter_name!(node.name)

      if node.instance != nil do
        filter_name!(node.instance)
      end

      validate_args!(node.args)
    end
  end

  defp validate_node!(_node, node_id),
    do: raise(ArgumentError, "invalid graph node #{inspect(node_id)}")

  defp validate_node_inputs!(%Node{kind: :filter, name: name} = node, nodes) when is_atom(name) do
    if Map.has_key?(Metadata.filters(), name) do
      case Shape.resolve(name, :outputs, node.args) do
        {:ok, media} when media != node.output_media ->
          raise ArgumentError, "invalid output media/count for #{name}"

        _ ->
          :ok
      end

      expected =
        case Shape.resolve(name, :inputs, node.args) do
          {:ok, media} ->
            unless length(media) == length(node.inputs) do
              raise ArgumentError, "invalid input count for #{name}"
            end

            media

          {:unresolved, _reason} ->
            fixed_inputs =
              Metadata.filter!(name).inputs
              |> Enum.filter(&(&1 in [:A, :V]))
              |> Enum.map(fn
                :A -> :audio
                :V -> :video
              end)

            if length(node.inputs) < length(fixed_inputs) do
              raise ArgumentError, "missing fixed input pads for #{name}"
            end

            fixed_inputs
        end

      Enum.zip(node.inputs, expected)
      |> Enum.each(fn {ref, media} ->
        actual = Enum.fetch!(nodes[ref.node_id].output_media, ref.output)

        if actual not in [:unknown, media] do
          raise ArgumentError, "#{name} expects #{media} input, got: #{actual}"
        end
      end)
    end
  end

  defp validate_node_inputs!(_node, _nodes), do: :ok

  defp validate_ref!(%Ref{node_id: node_id, output: output}, nodes, context) do
    case Map.get(nodes, node_id) do
      %Node{output_media: media} = node
      when is_integer(output) and output >= 0 and output < length(media) ->
        node

      _ ->
        raise ArgumentError,
              "invalid #{context} ref #{inspect({node_id, output})}; referenced pads must exist and precede their consumers"
    end
  end

  defp validate_ref!(ref, _nodes, context),
    do: raise(ArgumentError, "invalid #{context} ref: #{inspect(ref)}")

  defp validate_connected_outputs!(graph, allow_unused) do
    nodes = Graph.nodes(graph)
    inputs = Enum.flat_map(nodes, & &1.inputs)
    exports = Enum.map(graph.exports, & &1.ref)
    consumers = Enum.frequencies(inputs ++ exports)
    filters = Enum.filter(nodes, &(&1.kind == :filter))

    Enum.each(filters, fn node ->
      node.output_media
      |> Enum.with_index()
      |> Enum.each(fn {_media, output} ->
        ref = %Ref{node_id: node.id, output: output}
        count = Map.get(consumers, ref, 0)

        if count == 0 and not allow_unused do
          raise ArgumentError,
                "unconnected filter output #{inspect({node.id, output})}; every produced output must be consumed or exported"
        end

        if count > 1 do
          raise ArgumentError,
                "filter output #{inspect({node.id, output})} is used #{count} times; use split/asplit for multiple consumers"
        end
      end)
    end)
  end

  defp validate_args!(args) when is_list(args) do
    Enum.each(args, fn
      {:pos, value} ->
        validate_argument_value!(value)

      {key, value} when is_atom(key) or is_binary(key) ->
        option_name!(key)
        validate_argument_value!(value)

      other ->
        raise ArgumentError, "invalid filter argument: #{inspect(other)}"
    end)
  end

  defp validate_args!(_args), do: raise(ArgumentError, "filter arguments must be an ordered list")

  defp validate_argument_value!(value) when is_list(value), do: Enum.each(value, &value!/1)
  defp validate_argument_value!(value), do: value!(value)

  @spec selector!(InputRef.selector()) :: InputRef.selector()
  def selector!(selector) do
    selector = InputRef.normalize_selector!(selector)

    if selector == :all or match?({_media, :all}, selector) do
      raise ArgumentError,
            "graph inputs require one stream; use a selection for broad output mappings"
    end

    selector
  end

  @spec filter_name!(atom() | String.t()) :: String.t()
  def filter_name!(name) when is_atom(name) and name not in [nil, true, false],
    do: filter_name!(Atom.to_string(name))

  def filter_name!(name) do
    if is_binary(name) and String.match?(name, ~r/\A[a-zA-Z0-9_]+\z/) do
      name
    else
      raise ArgumentError, "filter name must be an identifier, got: #{inspect(name)}"
    end
  end

  @spec media!(FFix.Graph.StreamRef.media()) :: FFix.Graph.StreamRef.media()
  def media!(media) do
    unless media in [:audio, :video, :unknown] do
      raise ArgumentError,
            "output media must be :audio, :video, or :unknown, got: #{inspect(media)}"
    end

    media
  end

  @spec option_name!(atom() | String.t()) :: String.t()
  def option_name!(key) do
    name = to_string(key)

    if key not in [nil, true, false] and String.match?(name, ~r{\A/?[a-zA-Z0-9_][a-zA-Z0-9_-]*\z}) do
      name
    else
      raise ArgumentError, "filter option name must be an unscoped name, got: #{inspect(key)}"
    end
  end

  @spec value!(term()) :: String.t() | number() | boolean()
  def value!(value) when is_binary(value) do
    if String.contains?(value, <<0>>) do
      raise ArgumentError, "filter option values cannot contain NUL"
    end

    value
  end

  def value!(value) when is_number(value) or is_boolean(value), do: value

  def value!(value) when is_atom(value) and not is_nil(value), do: value!(Atom.to_string(value))

  def value!(other) do
    raise ArgumentError,
          "filter option values must be scalars or expressions; use strings for compound values, got: #{inspect(other)}"
  end

  @spec settings!([Graph.setting()]) :: [Graph.setting()]
  def settings!(settings) when is_list(settings) do
    Enum.reduce(settings, MapSet.new(), fn
      {key, value}, names when is_atom(key) or is_binary(key) ->
        name = filter_name!(key)

        if name != "sws_flags" do
          raise ArgumentError, "unsupported graph setting: #{name}"
        end

        if MapSet.member?(names, name) do
          raise ArgumentError, "duplicate graph setting: #{name}"
        end

        validate_argument_value!(value)

        MapSet.put(names, name)

      other, _names ->
        raise ArgumentError, "invalid graph setting: #{inspect(other)}"
    end)

    settings
  end

  def settings!(_settings), do: raise(ArgumentError, "graph settings must be an ordered list")
end
