defmodule FF.Graph.Parse do
  @moduledoc false

  alias FF.Graph
  alias FF.Graph.Export
  alias FF.Graph.InputRef
  alias FF.Graph.Node
  alias FF.Graph.Ref

  @type state :: %{
          nodes: %{Graph.node_id() => Node.t()},
          order: [Graph.node_id()],
          next_id: pos_integer(),
          input_nodes: %{InputRef.t() => Graph.node_id()},
          labels: %{String.t() => Ref.t()},
          used_labels: MapSet.t(String.t()),
          outputs: [%{label: String.t(), ref: Ref.t(), generated?: boolean()}],
          settings: [{String.t(), term()}],
          node_label_counts: %{atom() => non_neg_integer()}
        }

  @spec parse!(String.t()) :: Graph.t()
  def parse!(source) when is_binary(source) do
    statements =
      source
      |> split_unescaped(?;)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if statements == [] do
      raise ArgumentError, "empty filtergraph"
    end

    statements
    |> Enum.reduce(new_state(), &apply_statement/2)
    |> to_graph()
    |> FF.validate!()
  end

  defp new_state do
    %{
      nodes: %{},
      order: [],
      next_id: 1,
      input_nodes: %{},
      labels: %{},
      used_labels: MapSet.new(),
      outputs: [],
      settings: [],
      node_label_counts: %{}
    }
  end

  defp apply_statement(statement, state) do
    if String.contains?(statement, "[") do
      add_filter(statement, state)
    else
      add_setting(statement, state)
    end
  end

  defp add_setting(statement, state) do
    case split_once_unescaped(statement, ?=) do
      {key, value} ->
        %{state | settings: state.settings ++ [{key, parse_setting_value(value)}]}

      nil ->
        raise ArgumentError, "invalid graph setting: #{inspect(statement)}"
    end
  end

  defp add_filter(statement, state) do
    {input_labels, rest} = take_labels(statement)
    {name, instance, rest} = take_filter_name(rest)
    {args, output_labels} = take_args_and_outputs(rest)
    {input_refs, state} = Enum.map_reduce(input_labels, state, &resolve_input/2)

    node_name = String.to_atom(name)
    node_id = state.next_id
    output_count = length(output_labels)

    node = %Node{
      id: node_id,
      kind: :filter,
      name: node_name,
      instance: instance,
      inputs: input_refs,
      args: args,
      outputs: output_count,
      media: infer_media(input_refs, state.nodes)
    }

    {node_label, state} = next_node_label(state, node_name)

    state = %{
      state
      | nodes: Map.put(state.nodes, node_id, node),
        order: state.order ++ [node_id],
        next_id: node_id + 1
    }

    Enum.with_index(output_labels)
    |> Enum.reduce(state, fn {label, output}, state ->
      ref = %Ref{node_id: node_id, output: output}
      generated? = label == generated_output_label(node_label, output_count, output)

      %{
        state
        | labels: Map.put(state.labels, label, ref),
          outputs: state.outputs ++ [%{label: label, ref: ref, generated?: generated?}]
      }
    end)
  end

  defp to_graph(state) do
    terminals =
      state.nodes
      |> Map.values()
      |> Enum.filter(&(&1.kind == :filter and &1.outputs == 0))
      |> Enum.map(& &1.id)

    exports =
      state.outputs
      |> Enum.reject(&MapSet.member?(state.used_labels, &1.label))
      |> Enum.reject(& &1.generated?)
      |> Enum.map(fn %{label: label, ref: ref} ->
        %Export{name: export_name(label), ref: ref}
      end)

    %Graph{
      nodes: state.nodes,
      order: state.order,
      exports: exports,
      terminals: terminals,
      settings: state.settings
    }
  end

  defp resolve_input(label, state) do
    case parse_input_ref(label) do
      %InputRef{} = input_ref -> ensure_input_node(state, input_ref)
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

        state = %{
          state
          | nodes: Map.put(state.nodes, node_id, node),
            order: state.order ++ [node_id],
            next_id: node_id + 1,
            input_nodes: Map.put(state.input_nodes, input_ref, node_id)
        }

        {ref, state}

      node_id ->
        {%Ref{node_id: node_id, output: 0}, state}
    end
  end

  defp take_filter_name(""), do: raise(ArgumentError, "missing filter name")

  defp take_filter_name(source) do
    end_index =
      source
      |> String.to_charlist()
      |> Enum.find_index(&(&1 in ~c"=["))
      |> Kernel.||(String.length(source))

    name = binary_part(source, 0, end_index)
    rest = binary_part(source, end_index, byte_size(source) - end_index)

    case String.split(name, "@", parts: 2) do
      [filter_name] -> {filter_name, nil, rest}
      [filter_name, instance] -> {filter_name, instance, rest}
    end
  end

  defp take_args_and_outputs(""), do: {[], []}

  defp take_args_and_outputs(<<"[", _::binary>> = source) do
    {parse_labels(source), []}
    |> case do
      {labels, []} -> {[], labels}
    end
  end

  defp take_args_and_outputs(<<"=", rest::binary>>) do
    case find_unescaped(rest, ?[) do
      nil -> {parse_args(rest), []}
      index ->
        args = binary_part(rest, 0, index)
        outputs = binary_part(rest, index, byte_size(rest) - index)
        {parse_args(args), parse_labels(outputs)}
    end
  end

  defp take_args_and_outputs(source) do
    raise ArgumentError, "invalid filter tail: #{inspect(source)}"
  end

  defp take_labels(source), do: take_labels(source, [])

  defp take_labels(<<"[", rest::binary>>, labels) do
    case :binary.match(rest, "]") do
      {index, 1} ->
        label = binary_part(rest, 0, index)
        next = binary_part(rest, index + 1, byte_size(rest) - index - 1)
        take_labels(next, labels ++ [label])

      :nomatch ->
        raise ArgumentError, "unterminated label"
    end
  end

  defp take_labels(source, labels), do: {labels, source}

  defp parse_labels(source) do
    case take_labels(source) do
      {labels, ""} -> labels
      {_labels, rest} -> raise ArgumentError, "invalid output labels: #{inspect(rest)}"
    end
  end

  defp parse_args(""), do: []

  defp parse_args(source) do
    source
    |> split_unescaped(?:)
    |> Enum.map(&parse_arg/1)
  end

  defp parse_arg(token) do
    case split_once_unescaped(token, ?=) do
      {key, value} -> {key, parse_value(value)}
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

  defp parse_scalar(""), do: nil
  defp parse_scalar(source), do: unescape(source)

  defp parse_input_ref(label) do
    case Regex.run(~r/^(\d+):v:(\d+)$/, label) do
      [_, input, stream] ->
        %InputRef{input: String.to_integer(input), selector: {:video, String.to_integer(stream)}}

      nil ->
        case Regex.run(~r/^(\d+):a:(\d+)$/, label) do
          [_, input, stream] ->
            %InputRef{input: String.to_integer(input), selector: {:audio, String.to_integer(stream)}}

          nil ->
            case Regex.run(~r/^(\d+):v$/, label) do
              [_, input] -> %InputRef{input: String.to_integer(input), selector: :video}
              nil ->
                case Regex.run(~r/^(\d+):a$/, label) do
                  [_, input] -> %InputRef{input: String.to_integer(input), selector: :audio}
                  nil -> parse_raw_input_ref(label)
                end
            end
        end
    end
  end

  defp parse_raw_input_ref(label) do
    case Regex.run(~r/^(\d+):(.+)$/, label) do
      [_, input, selector] -> %InputRef{input: String.to_integer(input), selector: {:raw, selector}}
      nil -> nil
    end
  end

  defp next_node_label(state, name) do
    count = Map.get(state.node_label_counts, name, 0)
    label = if count == 0, do: Atom.to_string(name), else: "#{name}_#{count}"

    {label, %{state | node_label_counts: Map.put(state.node_label_counts, name, count + 1)}}
  end

  # Exports are inferred from labels that remain unused and differ from FF's
  # generated intermediate label scheme. This keeps parsing aligned with the
  # renderer without pretending to cover arbitrary ffmpeg graphs yet.
  defp generated_output_label(node_label, outputs, output) when outputs > 1 do
    "#{node_label}_#{output}"
  end

  defp generated_output_label(node_label, 1, 0), do: node_label
  defp generated_output_label(_node_label, _outputs, _output), do: nil

  defp export_name(label) do
    if String.match?(label, ~r/^out\d+$/) do
      nil
    else
      String.to_atom(label)
    end
  end

  defp infer_media([], _nodes), do: :unknown

  defp infer_media(refs, nodes) do
    case refs |> Enum.map(&Map.fetch!(nodes, &1.node_id).media) |> Enum.uniq() do
      [media] -> media
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
      nil -> nil
      index ->
        head = binary_part(source, 0, index)
        tail = binary_part(source, index + 1, byte_size(source) - index - 1)
        {head, tail}
    end
  end

  defp find_unescaped(source, separator), do: find_unescaped(source, separator, 0, false)

  defp find_unescaped(<<>>, _separator, _index, _escaped), do: nil

  defp find_unescaped(<<?\\, rest::binary>>, separator, index, false) do
    find_unescaped(rest, separator, index + 1, true)
  end

  defp find_unescaped(<<_char, rest::binary>>, separator, index, true) do
    find_unescaped(rest, separator, index + 1, false)
  end

  defp find_unescaped(<<separator, _rest::binary>>, separator, index, false), do: index

  defp find_unescaped(<<_char, rest::binary>>, separator, index, false) do
    find_unescaped(rest, separator, index + 1, false)
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
