defmodule FFix.Graph.Render do
  @moduledoc false

  alias FFix.Graph.Expr
  alias FFix.Graph
  alias FFix.Graph.Export
  alias FFix.Graph.InputRef
  alias FFix.Graph.Node
  alias FFix.Graph.Ref

  @type render_result :: %{
          graph: String.t(),
          exports: [%{name: Export.name() | nil, label: String.t(), ref: Ref.t()}]
        }

  @spec render(Graph.t()) :: render_result()
  def render(%Graph{} = graph) do
    node_labels = build_node_labels(graph)
    output_labels = build_output_labels(graph, node_labels)

    lines =
      settings_lines(graph.settings) ++
        Enum.flat_map(graph.order, fn node_id ->
          case render_node(Map.fetch!(graph.nodes, node_id), graph.nodes, output_labels) do
            nil -> []
            line -> [line]
          end
        end)

    %{
      graph: Enum.join(lines, "\n"),
      exports: render_exports(graph.exports, output_labels)
    }
  end

  @spec to_filtergraph(Graph.t()) :: String.t()
  def to_filtergraph(%Graph{} = graph) do
    graph
    |> render()
    |> Map.fetch!(:graph)
  end

  defp settings_lines(settings) do
    Enum.map(settings, fn {key, value} ->
      "#{key}=#{encode_setting_value(value)};"
    end)
  end

  defp render_node(%Node{kind: :input}, _nodes, _output_labels), do: nil

  defp render_node(%Node{} = node, nodes, output_labels) do
    inputs = Enum.map_join(node.inputs, "", &input_label(&1, nodes, output_labels))
    args = args_to_string(node.args)
    outputs = outputs_to_string(node, output_labels)

    inputs <> filter_name(node) <> args <> outputs <> ";"
  end

  defp filter_name(%Node{instance: nil, name: name}), do: to_string(name)
  defp filter_name(%Node{name: name, instance: instance}), do: "#{name}@#{instance}"

  defp input_label(%Ref{} = ref, nodes, output_labels) do
    node = Map.fetch!(nodes, ref.node_id)

    case node.kind do
      :input ->
        "[#{input_ref_to_string(node.input_ref)}]"

      :filter ->
        label = Map.fetch!(output_labels, ref_key(ref))
        "[#{label}]"
    end
  end

  defp outputs_to_string(%Node{outputs: 0}, _output_labels), do: ""

  defp outputs_to_string(%Node{} = node, output_labels) do
    0..(node.outputs - 1)
    |> Enum.map_join("", fn output ->
      case Map.get(output_labels, {node.id, output}) do
        nil -> ""
        label -> "[#{label}]"
      end
    end)
  end

  defp args_to_string([]), do: ""

  defp args_to_string(args) do
    encoded =
      Enum.map_join(args, ":", fn
        {:pos, value} -> encode_value(value)
        {key, value} -> "#{key}=#{encode_value(value)}"
      end)

    "=" <> encoded
  end

  defp encode_setting_value(value) when is_list(value) do
    Enum.map_join(value, "+", &encode_value/1)
  end

  defp encode_setting_value(value), do: encode_value(value)

  defp encode_value(%Expr{source: source}), do: escape_value(source)
  defp encode_value(value) when is_boolean(value), do: to_string(value)
  defp encode_value(value) when is_integer(value), do: Integer.to_string(value)
  defp encode_value(value) when is_float(value), do: :erlang.float_to_binary(value, [:compact])
  defp encode_value(value) when is_atom(value), do: Atom.to_string(value)
  defp encode_value(value) when is_list(value), do: Enum.map_join(value, "|", &encode_value/1)
  defp encode_value(value) when is_binary(value), do: escape_value(value)
  defp encode_value(nil), do: ""

  defp escape_value(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace(":", "\\:")
    |> String.replace(",", "\\,")
    |> String.replace(";", "\\;")
    |> String.replace("[", "\\[")
    |> String.replace("]", "\\]")
    |> String.replace("'", "\\'")
  end

  defp input_ref_to_string(%InputRef{input: input, selector: :input}),
    do: "#{graph_input_id!(input)}"

  defp input_ref_to_string(%InputRef{input: input, selector: :video}),
    do: "#{graph_input_id!(input)}:v"

  defp input_ref_to_string(%InputRef{input: input, selector: :audio}),
    do: "#{graph_input_id!(input)}:a"

  defp input_ref_to_string(%InputRef{input: input, selector: {:video, stream}}),
    do: "#{graph_input_id!(input)}:v:#{stream}"

  defp input_ref_to_string(%InputRef{input: input, selector: {:audio, stream}}),
    do: "#{graph_input_id!(input)}:a:#{stream}"

  defp input_ref_to_string(%InputRef{input: input, selector: {:raw, selector}}),
    do: "#{graph_input_id!(input)}:#{selector}"

  defp graph_input_id!(input) when is_integer(input), do: input

  defp graph_input_id!(input) do
    raise ArgumentError, "graph input #{inspect(input)} requires command input resolution"
  end

  defp render_exports(exports, output_labels) do
    Enum.map(exports, fn %Export{name: name, ref: ref} ->
      %{name: name, ref: ref, label: Map.fetch!(output_labels, ref_key(ref))}
    end)
  end

  defp build_node_labels(%Graph{} = graph) do
    {labels, _counts} =
      Enum.reduce(graph.order, {%{}, %{}}, fn node_id, {labels, counts} ->
        node = Map.fetch!(graph.nodes, node_id)

        if node.kind == :filter do
          name = to_string(node.name)
          count = Map.get(counts, name, 0)
          label = if count == 0, do: name, else: "#{name}_#{count}"

          {Map.put(labels, node_id, label), Map.put(counts, name, count + 1)}
        else
          {labels, counts}
        end
      end)

    labels
  end

  defp build_output_labels(%Graph{} = graph, node_labels) do
    {labels, used_labels} = export_labels(graph.exports)
    used_outputs = used_outputs(graph)

    Enum.reduce(graph.order, {labels, used_labels}, fn node_id, {labels, used_labels} ->
      node = Map.fetch!(graph.nodes, node_id)

      if node.kind == :filter do
        required_outputs = required_outputs(node, used_outputs)
        preferred_labels = preferred_output_labels(node)

        Enum.reduce(required_outputs, {labels, used_labels}, fn output, {labels, used_labels} ->
          key = {node_id, output}

          if Map.has_key?(labels, key) do
            {labels, used_labels}
          else
            preferred_label = Map.get(preferred_labels, output)
            base_label = preferred_label || "#{Map.fetch!(node_labels, node_id)}_#{output}"
            label = unique_label(base_label, used_labels)
            {Map.put(labels, key, label), MapSet.put(used_labels, label)}
          end
        end)
      else
        {labels, used_labels}
      end
    end)
    |> elem(0)
  end

  defp preferred_output_labels(%Node{metadata: %{preferred_labels: labels}}), do: labels
  defp preferred_output_labels(%Node{}), do: %{}

  defp export_labels(exports) do
    Enum.with_index(exports)
    |> Enum.reduce({%{}, MapSet.new()}, fn {%Export{name: name, ref: ref}, index},
                                           {labels, used} ->
      base_label = if name, do: to_string(name), else: "out#{index}"
      label = unique_label(base_label, used)

      {Map.put(labels, ref_key(ref), label), MapSet.put(used, label)}
    end)
  end

  # Multi-output filters need labels for every output so later outputs stay addressable.
  defp required_outputs(%Node{outputs: outputs}, _used_outputs) when outputs > 1 do
    Enum.to_list(0..(outputs - 1))
  end

  defp required_outputs(%Node{id: node_id, outputs: 1}, used_outputs) do
    if MapSet.member?(used_outputs, {node_id, 0}), do: [0], else: []
  end

  defp required_outputs(%Node{}, _used_outputs), do: []

  defp used_outputs(%Graph{} = graph) do
    input_refs =
      graph.nodes
      |> Map.values()
      |> Enum.flat_map(& &1.inputs)
      |> Enum.map(&ref_key/1)

    export_refs = Enum.map(graph.exports, &ref_key(&1.ref))

    MapSet.new(input_refs ++ export_refs)
  end

  defp ref_key(%Ref{node_id: node_id, output: output}), do: {node_id, output}

  defp unique_label(base, used_labels) do
    if MapSet.member?(used_labels, base) do
      Stream.iterate(1, &(&1 + 1))
      |> Enum.find_value(fn suffix ->
        candidate = "#{base}_#{suffix}"
        if MapSet.member?(used_labels, candidate), do: nil, else: candidate
      end)
    else
      base
    end
  end
end
