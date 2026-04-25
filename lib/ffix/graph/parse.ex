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
          used_labels: MapSet.t(String.t()),
          export_candidates: [%{label: String.t() | nil, ref: Ref.t()}],
          settings: [{String.t(), term()}]
        }

  @spec parse!(String.t()) :: Graph.t()
  def parse!(source) when is_binary(source) do
    source
    |> FilterGraph.parse()
    |> Enum.reduce(new_state(), &apply_statement/2)
    |> to_graph()
    |> FFix.validate!()
  end

  defp new_state do
    %{
      nodes: %{},
      order: [],
      next_id: 1,
      input_nodes: %{},
      labels: %{},
      used_labels: MapSet.new(),
      export_candidates: [],
      settings: []
    }
  end

  defp apply_statement({:setting, key, value}, state) do
    %{state | settings: [{key, parse_setting_value(value)} | state.settings]}
  end

  defp apply_statement({:chain, filters}, state) do
    {state, pending_outputs} = Enum.reduce(filters, {state, []}, &add_filter/2)
    export_pending_outputs(state, pending_outputs)
  end

  defp add_filter(%{inputs: input_labels} = filter, {state, pending_outputs}) do
    name = Metadata.filter_name!(filter.name)
    args = parse_args(filter.args)

    {expected_inputs, expected_outputs} =
      filter_signature(
        name,
        args,
        length(input_labels) + length(pending_outputs),
        length(filter.outputs)
      )

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
      media: infer_media(name, explicit_inputs ++ implicit_inputs, state.nodes),
      metadata: preferred_label_metadata(preferred_labels)
    }

    state = put_node(state, node)

    {labeled_refs, pending_refs} = Enum.split(refs, length(filter.outputs))

    state =
      Enum.zip(filter.outputs, labeled_refs)
      |> Enum.reduce(state, fn {label, ref}, state ->
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

    terminals =
      state.nodes
      |> Map.values()
      |> Enum.filter(&(&1.kind == :filter and &1.outputs == 0))
      |> Enum.map(& &1.id)

    exports =
      Enum.flat_map(export_candidates, fn
        %{label: nil, ref: ref} ->
          [%Export{name: nil, ref: ref}]

        %{label: label, ref: ref} ->
          if MapSet.member?(state.used_labels, label) do
            []
          else
            [%Export{name: export_name(label), ref: ref}]
          end
      end)

    %Graph{
      nodes: state.nodes,
      order: order,
      exports: exports,
      terminals: terminals,
      settings: settings
    }
  end

  defp resolve_input(label, state) do
    case parse_input_ref(label) do
      %InputRef{} = input_ref ->
        ensure_input_node(state, input_ref)

      nil ->
        case state.labels[label] do
          nil -> raise ArgumentError, "unknown input label #{inspect(label)}"
          ref -> {ref, %{state | used_labels: MapSet.put(state.used_labels, label)}}
        end
    end
  end

  defp ensure_input_node(state, input_ref) do
    case state.input_nodes[input_ref] do
      nil ->
        node_id = state.next_id

        node = %Node{
          id: node_id,
          kind: :input,
          name: :input,
          input_ref: input_ref,
          outputs: 1,
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

  defp filter_signature(:concat, args, fallback_inputs, _fallback_outputs) do
    option_specs = Metadata.filter_spec(:concat)

    segments =
      integer_arg(args, "n") || Metadata.option_default(option_specs[:n]) || fallback_inputs || 1

    video_outputs = integer_arg(args, "v") || Metadata.option_default(option_specs[:v]) || 0
    audio_outputs = integer_arg(args, "a") || Metadata.option_default(option_specs[:a]) || 0

    {segments * (video_outputs + audio_outputs), video_outputs + audio_outputs}
  end

  defp filter_signature(name, args, fallback_inputs, fallback_outputs) do
    filter = Metadata.filter!(name)
    option_specs = Metadata.filter_spec(name)

    {input_count(filter.inputs, args, option_specs, fallback_inputs),
     output_count(filter.outputs, args, option_specs, fallback_outputs)}
  end

  defp input_count(io, args, option_specs, fallback_count) do
    io = Enum.reject(io, &(&1 == :|))

    case io do
      [] -> 0
      [:N] -> Metadata.dynamic_count_from_args(option_specs, :inputs, args) || fallback_count || 1
      many -> length(many)
    end
  end

  defp output_count(io, args, option_specs, fallback_count) do
    io = Enum.reject(io, &(&1 == :|))

    case io do
      [] ->
        0

      [:N] ->
        Metadata.dynamic_count_from_args(option_specs, :outputs, args) || fallback_count || 1

      many ->
        length(many)
    end
  end

  defp integer_arg(args, key) do
    Enum.find_value(args, fn
      {^key, value} when is_integer(value) ->
        value

      {^key, value} when is_binary(value) ->
        case Integer.parse(value) do
          {integer, ""} -> integer
          _ -> nil
        end

      {_other, _value} ->
        nil
    end)
  end

  defp parse_args(nil), do: []
  defp parse_args(""), do: []

  defp parse_args(source) do
    source
    |> split_unescaped(?:)
    |> Enum.map(&parse_arg/1)
  end

  defp parse_arg(token) do
    case split_once_unescaped(token, ?=) do
      {key, value} -> {String.trim(key), parse_value(value)}
      nil -> {:pos, parse_value(token)}
    end
  end

  defp parse_value(source) do
    case split_unescaped(source, ?|) do
      [single] -> parse_scalar(single)
      many -> Enum.map(many, &parse_scalar/1)
    end
  end

  defp parse_setting_value(source) do
    case split_unescaped(source, ?+) do
      [single] -> parse_scalar(single)
      many -> Enum.map(many, &parse_scalar/1)
    end
  end

  defp parse_scalar(source) do
    source = String.trim(source)

    if String.starts_with?(source, "'") and String.ends_with?(source, "'") and
         byte_size(source) >= 2 do
      source
      |> binary_part(1, byte_size(source) - 2)
      |> unescape()
    else
      unescape(source)
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

  defp infer_media(name, refs, nodes) do
    case refs |> Enum.map(&Map.fetch!(nodes, &1.node_id).media) |> Enum.uniq() do
      [media] -> media
      _ -> filter_output_media(name)
    end
  end

  defp filter_output_media(name) do
    name
    |> Metadata.filter!()
    |> Map.fetch!(:outputs)
    |> Enum.reject(&(&1 == :|))
    |> Enum.uniq()
    |> case do
      [:V] -> :video
      [:A] -> :audio
      _ -> :unknown
    end
  end

  defp selector_media(:video), do: :video
  defp selector_media(:audio), do: :audio
  defp selector_media({:video, _}), do: :video
  defp selector_media({:audio, _}), do: :audio
  defp selector_media(_), do: :unknown

  defp split_unescaped(source, separator) do
    case split_once_unescaped(source, separator) do
      nil -> [source]
      {head, tail} -> [head | split_unescaped(tail, separator)]
    end
  end

  defp split_once_unescaped(source, separator) do
    case find_unescaped(source, separator) do
      nil ->
        nil

      index ->
        head = binary_part(source, 0, index)
        tail = binary_part(source, index + 1, byte_size(source) - index - 1)
        {head, tail}
    end
  end

  defp find_unescaped(source, separator), do: find_unescaped(source, separator, 0, false, false)
  defp find_unescaped(<<>>, _separator, _index, _escaped, _quoted), do: nil

  defp find_unescaped(<<?\\, rest::binary>>, separator, index, false, quoted) do
    find_unescaped(rest, separator, index + 1, true, quoted)
  end

  defp find_unescaped(<<_char, rest::binary>>, separator, index, true, quoted) do
    find_unescaped(rest, separator, index + 1, false, quoted)
  end

  defp find_unescaped(<<?', rest::binary>>, separator, index, false, false) do
    find_unescaped(rest, separator, index + 1, false, true)
  end

  defp find_unescaped(<<?', rest::binary>>, separator, index, false, true) do
    find_unescaped(rest, separator, index + 1, false, false)
  end

  defp find_unescaped(<<separator, _rest::binary>>, separator, index, false, false), do: index

  defp find_unescaped(<<_char, rest::binary>>, separator, index, false, quoted) do
    find_unescaped(rest, separator, index + 1, false, quoted)
  end

  defp unescape(source), do: unescape(source, [])

  defp unescape(<<>>, acc), do: acc |> Enum.reverse() |> IO.iodata_to_binary()
  defp unescape(<<?\\>>, acc), do: unescape(<<>>, ["\\" | acc])

  defp unescape(<<?\\, char, rest::binary>>, acc) do
    unescape(rest, [<<char>> | acc])
  end

  defp unescape(<<char, rest::binary>>, acc) do
    unescape(rest, [<<char>> | acc])
  end
end
