defmodule FFix.Graph.Render do
  @moduledoc false

  alias FFix.Graph
  alias FFix.Graph.Export
  alias FFix.Graph.InputRef
  alias FFix.Graph.Node
  alias FFix.Graph.Ref

  @type render_result :: %{
          graph: String.t(),
          exports: [%{name: Export.name() | nil, label: String.t(), ref: Ref.t()}]
        }

  @doc "Renders a graph already checked by `FFix.Graph.Validator`."
  @spec render(Graph.t()) :: render_result()
  def render(%Graph{} = graph) do
    filters = Enum.filter(Graph.nodes(graph), &(&1.kind == :filter))
    node_labels = build_node_labels(filters)
    output_labels = build_output_labels(filters, graph.exports, node_labels)
    filter_lines = Enum.map(filters, &render_node(&1, graph.nodes, output_labels))
    lines = settings_lines(graph.settings) ++ filter_lines

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
        "[#{escape_graph(input_ref_to_string(node.input_ref))}]"

      :filter ->
        label = Map.fetch!(output_labels, ref_key(ref))
        "[#{label}]"
    end
  end

  defp outputs_to_string(%Node{} = node, output_labels) do
    node.output_media
    |> Enum.with_index()
    |> Enum.map_join("", fn {_media, output} ->
      "[#{Map.fetch!(output_labels, {node.id, output})}]"
    end)
  end

  defp args_to_string([]), do: ""

  defp args_to_string(args) do
    encoded =
      Enum.map_join(args, ":", fn
        {:pos, value} -> encode_value(value)
        {key, value} -> "#{key}=#{encode_value(value)}"
      end)

    "=" <> escape_graph(encoded)
  end

  defp encode_setting_value(value) when is_list(value) do
    value |> Enum.map_join("+", &encode_value/1) |> escape_graph()
  end

  defp encode_setting_value(value), do: value |> encode_value() |> escape_graph()

  defp encode_value(value) when is_boolean(value), do: to_string(value)
  defp encode_value(value) when is_integer(value), do: Integer.to_string(value)
  defp encode_value(value) when is_float(value), do: FFix.Value.float_to_string(value)
  defp encode_value(value) when is_atom(value), do: value |> Atom.to_string() |> escape_value()
  defp encode_value(value) when is_list(value), do: Enum.map_join(value, "|", &encode_value/1)
  defp encode_value(value) when is_binary(value), do: escape_value(value)

  # FFmpeg consumes option escaping after consuming filtergraph escaping. Neither
  # layer is shell quoting; this string is passed as one argv entry.
  defp escape_value(value), do: escape(value, ~c"\\':= \t\r\n")
  defp escape_graph(value), do: escape(value, ~c"\\'[],; \t\r\n")

  defp escape(value, special_chars) do
    value
    |> String.to_charlist()
    |> Enum.map(fn char ->
      if char in special_chars do
        [?\\, char]
      else
        char
      end
    end)
    |> List.to_string()
  end

  defp input_ref_to_string(%InputRef{input: input, selector: selector}) do
    input = graph_input_id!(input)
    suffix = InputRef.selector_string(selector)

    case suffix do
      "" -> to_string(input)
      suffix -> "#{input}:#{suffix}"
    end
  end

  defp graph_input_id!(input) when is_integer(input), do: input

  defp graph_input_id!(input) do
    raise ArgumentError, "graph input #{inspect(input)} requires command input resolution"
  end

  defp render_exports(exports, output_labels) do
    Enum.map(exports, fn %Export{name: name, ref: ref} ->
      %{name: name, ref: ref, label: Map.fetch!(output_labels, ref_key(ref))}
    end)
  end

  defp build_node_labels(filters) do
    {labels, _counts} =
      Enum.reduce(filters, {%{}, %{}}, fn node, {labels, counts} ->
        name = to_string(node.name)
        count = Map.get(counts, name, 0)

        label =
          case count do
            0 -> name
            count -> "#{name}_#{count}"
          end

        {Map.put(labels, node.id, label), Map.put(counts, name, count + 1)}
      end)

    labels
  end

  defp build_output_labels(filters, exports, node_labels) do
    initial = export_labels(exports)

    {labels, _used_labels} =
      Enum.reduce(filters, initial, fn node, labels ->
        preferred_labels = Map.get(node.metadata, :preferred_labels, %{})
        node_label = Map.fetch!(node_labels, node.id)

        node.output_media
        |> Enum.with_index()
        |> Enum.reduce(labels, fn {_media, output}, {labels, used_labels} ->
          key = {node.id, output}

          if Map.has_key?(labels, key) do
            {labels, used_labels}
          else
            preferred_label = Map.get(preferred_labels, output)
            fallback_label = "#{node_label}_#{output}"
            base_label = safe_label(preferred_label, fallback_label)
            label = unique_label(base_label, used_labels)
            {Map.put(labels, key, label), MapSet.put(used_labels, label)}
          end
        end)
      end)

    labels
  end

  defp export_labels(exports) do
    Enum.with_index(exports)
    |> Enum.reduce({%{}, MapSet.new()}, fn {%Export{name: name, ref: ref}, index},
                                           {labels, used} ->
      base_label = safe_label(name, "out#{index}")
      label = unique_label(base_label, used)

      {Map.put(labels, ref_key(ref), label), MapSet.put(used, label)}
    end)
  end

  defp ref_key(%Ref{node_id: node_id, output: output}), do: {node_id, output}

  defp safe_label(nil, fallback), do: fallback

  defp safe_label(name, fallback) do
    label = to_string(name)

    case String.match?(label, ~r/\A[A-Za-z0-9_]+\z/) do
      true -> label
      false -> fallback
    end
  end

  defp unique_label(base, used_labels, suffix \\ 0) do
    candidate =
      case suffix do
        0 -> base
        suffix -> "#{base}_#{suffix}"
      end

    if MapSet.member?(used_labels, candidate) do
      unique_label(base, used_labels, suffix + 1)
    else
      candidate
    end
  end
end
