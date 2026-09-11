defmodule FFix.Graph.Parse do
  @moduledoc false

  alias FFix.Filter.Metadata
  alias FFix.Graph
  alias FFix.Graph.Export
  alias FFix.Graph.InputRef
  alias FFix.Graph.Node
  alias FFix.Graph.Ref
  alias FFix.Parsers.FilterGraph

  @type state :: %{
          nodes: %{Graph.node_id() => Node.t()},
          order: [Graph.node_id()],
          next_id: pos_integer(),
          input_nodes: %{InputRef.t() => Graph.node_id()},
          labels: %{String.t() => Ref.t()},
          declared_labels: MapSet.t(String.t()),
          export_candidates: [%{label: String.t() | nil, ref: Ref.t()}],
          settings: [{String.t(), term()}]
        }

  @spec parse!(String.t()) :: Graph.t()
  def parse!(source) when is_binary(source) do
    statements = FilterGraph.parse(source)

    labels =
      Enum.flat_map(statements, fn
        {:chain, filters} -> Enum.flat_map(filters, & &1.outputs)
        {:setting, _, _} -> []
      end)

    statements
    |> Enum.reduce(new_state(MapSet.new(labels)), &apply_statement/2)
    |> to_graph()
    |> FFix.validate!()
  end

  defp new_state(labels) do
    %{
      nodes: %{},
      order: [],
      next_id: 1,
      input_nodes: %{},
      labels: %{},
      declared_labels: labels,
      export_candidates: [],
      settings: []
    }
  end

  defp apply_statement({:setting, key, value}, state) do
    %{state | settings: [{key, value} | state.settings]}
  end

  defp apply_statement({:chain, filters}, state) do
    {state, pending_outputs} = Enum.reduce(filters, {state, []}, &add_filter/2)
    export_pending_outputs(state, pending_outputs)
  end

  defp add_filter(%{inputs: input_labels} = filter, {state, pending_outputs}) do
    name = Metadata.filter_name!(filter.name)
    args = FilterGraph.parse_args(filter.args)

    {expected_inputs, output_media} =
      filter_signature(name, args, length(input_labels) + length(pending_outputs))

    expected_outputs = length(output_media)

    if length(input_labels) > expected_inputs do
      raise ArgumentError, "too many input labels for #{filter.name}"
    end

    if length(filter.outputs) > expected_outputs do
      raise ArgumentError, "too many output labels for #{filter.name}"
    end

    {explicit_inputs, state} = Enum.map_reduce(input_labels, state, &resolve_input/2)
    implicit_input_count = expected_inputs - length(explicit_inputs)
    {implicit_inputs, leftover_pending} = Enum.split(pending_outputs, implicit_input_count)

    if length(implicit_inputs) != implicit_input_count do
      raise ArgumentError, "missing input labels for #{filter.name}"
    end

    if leftover_pending != [] do
      raise ArgumentError, "unlabelled outputs must connect to the next filter or be labelled"
    end

    node_id = state.next_id

    refs =
      if expected_outputs == 0,
        do: [],
        else: Enum.map(0..(expected_outputs - 1), &%Ref{node_id: node_id, output: &1})

    preferred_labels =
      filter.outputs
      |> Enum.with_index()
      |> Map.new(fn {label, output} -> {output, label} end)

    node = %Node{
      id: node_id,
      kind: :filter,
      name: name,
      instance: filter.instance,
      inputs: explicit_inputs ++ implicit_inputs,
      args: args,
      outputs: expected_outputs,
      output_media: output_media,
      media:
        case Enum.uniq(output_media) do
          [media] -> media
          _ -> :unknown
        end,
      metadata: preferred_label_metadata(preferred_labels)
    }

    state = put_node(state, node)

    {labeled_refs, pending_refs} = Enum.split(refs, length(filter.outputs))

    state =
      Enum.zip(filter.outputs, labeled_refs)
      |> Enum.reduce(state, fn {label, ref}, state ->
        if Map.has_key?(state.labels, label),
          do: raise(ArgumentError, "duplicate graph label: #{inspect(label)}")

        %{
          state
          | labels: Map.put(state.labels, label, ref),
            export_candidates: [%{label: label, ref: ref} | state.export_candidates]
        }
      end)

    {state, pending_refs}
  end

  defp export_pending_outputs(state, refs) do
    Enum.reduce(refs, state, fn ref, state ->
      %{state | export_candidates: [%{label: nil, ref: ref} | state.export_candidates]}
    end)
  end

  defp to_graph(state) do
    order = Enum.reverse(state.order)
    settings = Enum.reverse(state.settings)
    export_candidates = Enum.reverse(state.export_candidates)

    graph_id = make_ref()

    terminals =
      Enum.filter(order, &(state.nodes[&1].kind == :filter and state.nodes[&1].outputs == 0))

    used_refs = state.nodes |> Map.values() |> Enum.flat_map(& &1.inputs) |> MapSet.new()

    exports =
      Enum.flat_map(export_candidates, fn %{label: label, ref: ref} ->
        if MapSet.member?(used_refs, ref) do
          []
        else
          name = if label != nil, do: export_name(label)

          [
            %Export{
              graph_id: graph_id,
              name: name,
              ref: ref,
              media: export_media(ref, state.nodes)
            }
          ]
        end
      end)

    %Graph{
      id: graph_id,
      nodes: state.nodes,
      order: order,
      exports: exports,
      terminals: terminals,
      settings: settings
    }
  end

  defp export_media(%Ref{node_id: node_id, output: output}, nodes),
    do: nodes |> Map.fetch!(node_id) |> Map.fetch!(:output_media) |> Enum.fetch!(output)

  defp resolve_input(label, state) do
    case Map.fetch(state.labels, label) do
      {:ok, ref} ->
        {ref, state}

      :error ->
        if MapSet.member?(state.declared_labels, label),
          do:
            raise(
              ArgumentError,
              "forward or cyclic graph label #{inspect(label)}; declare producers before consumers"
            )

        case parse_input_ref(label) do
          %InputRef{} = input_ref -> ensure_input_node(state, input_ref)
          nil -> raise ArgumentError, "unknown input label #{inspect(label)}"
        end
    end
  end

  defp ensure_input_node(state, input_ref) do
    InputRef.normalize_input_id!(input_ref.input)
    InputRef.normalize_selector!(input_ref.selector)

    case state.input_nodes[input_ref] do
      nil ->
        node_id = state.next_id

        node = %Node{
          id: node_id,
          kind: :input,
          name: :input,
          input_ref: input_ref,
          outputs: 1,
          output_media: [selector_media(input_ref.selector)],
          media: selector_media(input_ref.selector)
        }

        ref = %Ref{node_id: node_id, output: 0}

        state = put_node(state, node)
        state = %{state | input_nodes: Map.put(state.input_nodes, input_ref, node_id)}

        {ref, state}

      node_id ->
        {%Ref{node_id: node_id, output: 0}, state}
    end
  end

  defp put_node(state, %Node{id: node_id} = node) do
    %{
      state
      | nodes: Map.put(state.nodes, node_id, node),
        order: [node_id | state.order],
        next_id: node_id + 1
    }
  end

  defp filter_signature(name, args, supplied_inputs) do
    inputs =
      case FFix.Filter.Shape.resolve(name, :inputs, args) do
        {:ok, media} -> length(media)
        {:unresolved, _reason} -> supplied_inputs
      end

    case FFix.Filter.Shape.resolve(name, :outputs, args) do
      {:ok, output_media} -> {inputs, output_media}
      {:unresolved, reason} -> raise ArgumentError, "unresolved filter output shape: #{reason}"
    end
  end

  defp parse_input_ref(label) do
    case String.split(label, ":") do
      [input] -> build_input_ref(input, :input)
      [input, "v"] -> build_input_ref(input, :video)
      [input, "a"] -> build_input_ref(input, :audio)
      [input, "v", stream] -> build_stream_input_ref(input, stream, :video)
      [input, "a", stream] -> build_stream_input_ref(input, stream, :audio)
      [input | selector] -> build_raw_input_ref(input, Enum.join(selector, ":"))
      _ -> nil
    end
  end

  defp build_input_ref(input, selector) do
    with {input, ""} <- Integer.parse(input) do
      %InputRef{input: input, selector: selector}
    else
      _ -> nil
    end
  end

  defp build_stream_input_ref(input, stream, selector) do
    with {input, ""} <- Integer.parse(input),
         {stream, ""} <- Integer.parse(stream) do
      %InputRef{input: input, selector: {selector, stream}}
    else
      _ -> nil
    end
  end

  defp build_raw_input_ref(input, selector) do
    with {input, ""} <- Integer.parse(input),
         false <- selector == "" do
      %InputRef{input: input, selector: {:raw, selector}}
    else
      _ -> nil
    end
  end

  defp preferred_label_metadata(%{} = preferred_labels) when map_size(preferred_labels) == 0,
    do: %{}

  defp preferred_label_metadata(preferred_labels), do: %{preferred_labels: preferred_labels}

  defp export_name(label) do
    if String.match?(label, ~r/^out\d+$/) do
      nil
    else
      label
    end
  end

  defp selector_media(:video), do: :video
  defp selector_media(:audio), do: :audio
  defp selector_media({:video, _}), do: :video
  defp selector_media({:audio, _}), do: :audio
  defp selector_media(_), do: :unknown
end
