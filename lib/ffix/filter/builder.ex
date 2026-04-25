defmodule FFix.Filter.Builder do
  @moduledoc false

  alias FFix.Graph
  alias FFix.Graph.Export
  alias FFix.Graph.InputRef
  alias FFix.Graph.Node
  alias FFix.Graph.Ref
  alias FFix.Stream
  alias FFix.Terminal
  alias FFix.Filter.Metadata
  alias FFix.Value

  defmodule Plan do
    @moduledoc false

    @type t :: %__MODULE__{
            id: reference(),
            kind: :input | :filter,
            name: atom(),
            instance: String.t() | atom() | nil,
            input_ref: InputRef.t() | nil,
            inputs: [Stream.t()],
            args: [Node.arg()],
            outputs: non_neg_integer(),
            media: :audio | :video | :unknown
          }

    defstruct [
      :id,
      :kind,
      :name,
      :instance,
      :input_ref,
      inputs: [],
      args: [],
      outputs: 1,
      media: :unknown
    ]
  end

  @type input_id :: InputRef.input_id() | atom()
  @type input_selector :: InputRef.selector()

  @spec input(input_id(), input_selector()) :: Stream.t()
  def input(index, selector) do
    input_ref = %InputRef{input: InputRef.normalize_input_id!(index), selector: selector}

    plan = %Plan{
      id: make_ref(),
      kind: :input,
      name: :input,
      input_ref: input_ref,
      outputs: 1,
      media: selector_media(selector)
    }

    %Stream{plan: plan, output: 0, media: plan.media}
  end

  @spec input_raw(String.t()) :: Stream.t()
  def input_raw(spec) when is_binary(spec) do
    case Regex.run(~r/^(\d+):(.*)$/, spec) do
      [_, input, selector] ->
        input(String.to_integer(input), {:raw, selector})

      _ ->
        raise ArgumentError, "input_raw/1 expects a stream spec like \"0:v\""
    end
  end

  @spec filter(atom() | String.t(), [Stream.t()], keyword()) ::
          Stream.t() | Terminal.t() | [Stream.t()] | tuple()
  def filter(name, inputs, options \\ []) when is_list(inputs) do
    name = Metadata.filter_name!(name)
    %{outputs: outputs} = Metadata.filter!(name)
    option_specs = Metadata.filter_spec(name)

    apply_filter(name, inputs, outputs, options, option_specs)
  end

  @type output_media :: :audio | :video | :unknown

  @spec apply_filter(atom(), [Stream.t() | [Stream.t()]], [atom()], keyword(), map()) ::
          Stream.t() | Terminal.t() | [Stream.t()] | tuple()
  def apply_filter(name, inputs, outputs, options, option_specs) do
    inputs = normalize_inputs(inputs)
    validate_streams!(inputs)
    validate_options!(options, option_specs)

    {output_count, output_media} = output_shape(name, outputs, options, option_specs, inputs)

    plan = %Plan{
      id: make_ref(),
      kind: :filter,
      name: name,
      inputs: inputs,
      args: normalize_args(options, option_specs),
      outputs: output_count,
      media: summarize_media(output_media)
    }

    build_result(plan, outputs, output_media)
  end

  @spec shape(Stream.t() | [Stream.t()] | tuple(), [output_media()]) :: Stream.t() | [Stream.t()]
  def shape(result, outputs) when is_list(outputs) do
    output_media = Enum.map(outputs, &normalize_output_media!/1)

    if output_media == [] do
      raise ArgumentError, "shape/2 expects at least one output media type"
    end

    plan = result |> shape_streams!() |> shared_plan!()
    plan = %{plan | outputs: length(output_media), media: summarize_media(output_media)}

    build_shaped_result(plan, output_media)
  end

  @spec graph(keyword()) :: Graph.t()
  def graph(options) when is_list(options) do
    validate_graph_keys!(options)
    {exports, terminals} = normalize_roots(options)
    settings = normalize_settings(Keyword.get(options, :settings, []))

    plans = collect_plans(exports, terminals)
    {id_map, order} = assign_ids(plans)
    nodes = materialize_nodes(plans, id_map)

    graph_exports =
      Enum.map(exports, fn {name, %Stream{plan: plan, output: output}} ->
        %Export{name: name, ref: %Ref{node_id: id_map[plan.id], output: output}}
      end)

    graph_terminals = Enum.map(terminals, fn %Terminal{plan: plan} -> id_map[plan.id] end)

    %Graph{
      nodes: nodes,
      order: order,
      exports: graph_exports,
      terminals: graph_terminals,
      settings: settings
    }
  end

  @spec validate_graph!(Graph.t()) :: Graph.t()
  def validate_graph!(%Graph{} = graph) do
    Enum.each(graph.order, fn node_id ->
      node = Map.fetch!(graph.nodes, node_id)

      Enum.each(node.inputs, fn %Ref{node_id: input_id, output: output} ->
        input_node = Map.fetch!(graph.nodes, input_id)

        if output >= input_node.outputs do
          raise ArgumentError, "invalid input ref #{inspect({input_id, output})}"
        end
      end)
    end)

    Enum.each(graph.exports, fn %Export{ref: %Ref{node_id: node_id, output: output}} ->
      node = Map.fetch!(graph.nodes, node_id)

      if output >= node.outputs do
        raise ArgumentError, "invalid export ref #{inspect({node_id, output})}"
      end
    end)

    Enum.each(graph.terminals, fn node_id ->
      node = Map.fetch!(graph.nodes, node_id)

      if node.outputs != 0 do
        raise ArgumentError, "terminal #{node_id} must point to a sink node"
      end
    end)

    validate_connected_outputs!(graph)
    graph
  end

  defp normalize_inputs(inputs) do
    Enum.flat_map(inputs, fn
      %Stream{} = stream -> [stream]
      streams when is_list(streams) -> streams
    end)
  end

  defp validate_streams!(inputs) do
    Enum.each(inputs, fn
      %Stream{} -> :ok
      other -> raise ArgumentError, "expected FFix.Stream, got: #{inspect(other)}"
    end)
  end

  # Keep value normalization permissive so raw ffmpeg strings remain an escape hatch.
  defp validate_options!(options, specs) do
    Enum.each(options, fn
      {:pos, _value} ->
        :ok

      {key, _value} ->
        unless specs == %{} or Map.has_key?(specs, key) do
          raise ArgumentError, "#{key} is not a valid option"
        end
    end)

    :ok
  end

  defp normalize_args(options, specs) do
    Enum.map(options, fn
      {:pos, value} -> {:pos, Value.normalize(value, nil)}
      {key, value} -> {key, Value.normalize(value, Map.get(specs, key))}
    end)
  end

  defp output_shape(_name, [], _options, _option_specs, inputs) do
    {0, [infer_input_media(inputs)]}
  end

  defp output_shape(:concat, [:N], options, option_specs, _inputs) do
    output_media = concat_output_media(options, option_specs)
    {length(output_media), output_media}
  end

  defp output_shape(_name, [:N], options, option_specs, inputs) do
    count = dynamic_output_count(options, option_specs)
    {count, List.duplicate(infer_input_media(inputs), count)}
  end

  defp output_shape(_name, outputs, _options, _option_specs, _inputs) do
    output_media = Enum.map(outputs, &media_from_io/1)
    {length(output_media), output_media}
  end

  # Dynamic filters need a concrete output count once they become graph nodes.
  # Use normalized metadata defaults, with small per-filter overrides where ffmpeg's
  # output shape is determined by different options.
  defp dynamic_output_count(options, option_specs) do
    case Metadata.dynamic_count_from_options(option_specs, :outputs, options) do
      count when is_integer(count) and count > 0 -> count
      _ -> 1
    end
  end

  defp concat_output_media(options, option_specs) do
    video_outputs = integer_option(options, :v, option_specs)
    audio_outputs = integer_option(options, :a, option_specs)

    List.duplicate(:video, video_outputs) ++ List.duplicate(:audio, audio_outputs)
  end

  defp summarize_media(media) do
    case Enum.uniq(media) do
      [single] -> single
      _ -> :unknown
    end
  end

  defp infer_input_media([%Stream{media: media} | _]), do: media
  defp infer_input_media(_inputs), do: :unknown

  defp media_from_io(:A), do: :audio
  defp media_from_io(:V), do: :video
  defp media_from_io(_), do: :unknown

  defp build_result(plan, [], _output_media) do
    %Terminal{plan: plan, media: plan.media}
  end

  defp build_result(plan, [_single], [media]) do
    %Stream{plan: plan, output: 0, media: media}
  end

  defp build_result(plan, [:N], output_media) do
    Enum.with_index(output_media, fn media, output ->
      %Stream{plan: plan, output: output, media: media}
    end)
  end

  defp build_result(plan, _outputs, output_media) do
    output_media
    |> Enum.with_index(fn media, output ->
      %Stream{plan: plan, output: output, media: media}
    end)
    |> List.to_tuple()
  end

  defp build_shaped_result(plan, [media]) do
    %Stream{plan: plan, output: 0, media: media}
  end

  defp build_shaped_result(plan, output_media) do
    Enum.with_index(output_media, fn media, output ->
      %Stream{plan: plan, output: output, media: media}
    end)
  end

  defp validate_graph_keys!(options) do
    unknown = Keyword.keys(options) -- [:output, :outputs, :terminals, :settings]

    if unknown != [] do
      raise ArgumentError, "unknown graph keys: #{inspect(unknown)}"
    end
  end

  defp normalize_roots(options) do
    exports =
      cond do
        Keyword.has_key?(options, :output) and Keyword.has_key?(options, :outputs) ->
          raise ArgumentError, "use either :output or :outputs, not both"

        stream = Keyword.get(options, :output) ->
          [{nil, stream}]

        outputs = Keyword.get(options, :outputs) ->
          normalize_exports(outputs)

        true ->
          []
      end

    terminals = Keyword.get(options, :terminals, [])

    if exports == [] and terminals == [] do
      raise ArgumentError, "graph/1 expects at least one output or terminal"
    end

    validate_exports!(exports)
    validate_terminals!(terminals)

    {exports, terminals}
  end

  defp normalize_exports(outputs) when is_list(outputs) do
    Enum.map(outputs, fn
      {name, %Stream{} = stream} when is_atom(name) -> {name, stream}
      %Stream{} = stream -> {nil, stream}
    end)
  end

  defp validate_exports!(exports) do
    Enum.each(exports, fn
      {_name, %Stream{}} -> :ok
      other -> raise ArgumentError, "invalid graph export: #{inspect(other)}"
    end)
  end

  defp validate_terminals!(terminals) do
    Enum.each(terminals, fn
      %Terminal{} -> :ok
      other -> raise ArgumentError, "invalid graph terminal: #{inspect(other)}"
    end)
  end

  defp integer_option(options, key, option_specs) do
    case Keyword.get(options, key) do
      nil -> Metadata.option_default(option_specs[key]) || 0
      value -> parse_integer(value) || 0
    end
  end

  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp parse_integer(_value), do: nil

  defp normalize_output_media!(:audio), do: :audio
  defp normalize_output_media!(:video), do: :video
  defp normalize_output_media!(:unknown), do: :unknown

  defp normalize_output_media!(media) do
    raise ArgumentError,
          "shape/2 output media must be :audio, :video, or :unknown, got: #{inspect(media)}"
  end

  defp shape_streams!(%Stream{} = stream), do: [stream]
  defp shape_streams!(streams) when is_list(streams), do: streams
  defp shape_streams!(streams) when is_tuple(streams), do: Tuple.to_list(streams)

  defp shape_streams!(other) do
    raise ArgumentError,
          "shape/2 expects a filter result stream, list, or tuple, got: #{inspect(other)}"
  end

  defp shared_plan!([]) do
    raise ArgumentError, "shape/2 expects at least one stream"
  end

  defp shared_plan!([%Stream{plan: plan} | rest]) do
    Enum.each(rest, fn
      %Stream{plan: ^plan} ->
        :ok

      %Stream{} = stream ->
        raise ArgumentError,
              "shape/2 expects streams from one filter result, got: #{inspect(stream)}"

      other ->
        raise ArgumentError, "shape/2 expects FFix.Stream values, got: #{inspect(other)}"
    end)

    plan
  end

  defp validate_connected_outputs!(graph) do
    used_outputs =
      graph.nodes
      |> Map.values()
      |> Enum.flat_map(& &1.inputs)
      |> Enum.map(fn %Ref{node_id: node_id, output: output} -> {node_id, output} end)
      |> Kernel.++(
        Enum.map(graph.exports, fn %Export{ref: %Ref{node_id: node_id, output: output}} ->
          {node_id, output}
        end)
      )
      |> MapSet.new()

    Enum.each(graph.order, fn node_id ->
      case Map.fetch!(graph.nodes, node_id) do
        %Node{kind: :filter, outputs: outputs} when outputs > 0 ->
          Enum.each(0..(outputs - 1), fn output ->
            unless MapSet.member?(used_outputs, {node_id, output}) do
              raise ArgumentError,
                    "unconnected filter output #{inspect({node_id, output})}; every produced output must be consumed or exported"
            end
          end)

        _node ->
          :ok
      end
    end)
  end

  defp normalize_settings(settings) when is_list(settings) do
    Enum.map(settings, fn {key, value} -> {key, value} end)
  end

  defp collect_plans(exports, terminals) do
    export_streams = Enum.map(exports, fn {_name, stream} -> stream end)
    roots = export_streams ++ terminals

    {_seen, plans} =
      Enum.reduce(roots, {MapSet.new(), []}, fn root, acc ->
        visit_plan(plan_of(root), acc)
      end)

    plans
  end

  defp visit_plan(%Plan{id: id} = plan, {seen, plans}) do
    if MapSet.member?(seen, id) do
      {seen, plans}
    else
      {seen, plans} =
        Enum.reduce(plan.inputs, {MapSet.put(seen, id), plans}, fn input, acc ->
          visit_plan(input.plan, acc)
        end)

      {seen, plans ++ [plan]}
    end
  end

  defp plan_of(%Stream{plan: plan}), do: plan
  defp plan_of(%Terminal{plan: plan}), do: plan

  defp assign_ids(plans) do
    {id_map, order} =
      plans
      |> Enum.with_index(1)
      |> Enum.reduce({%{}, []}, fn {%Plan{id: plan_id}, node_id}, {id_map, order} ->
        {Map.put(id_map, plan_id, node_id), order ++ [node_id]}
      end)

    {id_map, order}
  end

  defp materialize_nodes(plans, id_map) do
    Map.new(plans, fn %Plan{} = plan ->
      node_id = Map.fetch!(id_map, plan.id)

      node = %Node{
        id: node_id,
        kind: plan.kind,
        name: plan.name,
        instance: plan.instance,
        input_ref: plan.input_ref,
        inputs: Enum.map(plan.inputs, &to_ref(&1, id_map)),
        args: plan.args,
        outputs: plan.outputs,
        media: plan.media
      }

      {node_id, node}
    end)
  end

  defp to_ref(%Stream{plan: plan, output: output}, id_map) do
    %Ref{node_id: Map.fetch!(id_map, plan.id), output: output}
  end

  defp selector_media(:input), do: :unknown
  defp selector_media(:video), do: :video
  defp selector_media(:audio), do: :audio
  defp selector_media({:video, _}), do: :video
  defp selector_media({:audio, _}), do: :audio
  defp selector_media(_), do: :unknown
end
