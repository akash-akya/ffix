defmodule FF.Filter.Builder do
  @moduledoc false

  alias FF.Graph
  alias FF.Graph.Export
  alias FF.Graph.InputRef
  alias FF.Graph.Node
  alias FF.Graph.Ref
  alias FF.Stream
  alias FF.Terminal
  alias FF.Filter.Help
  alias FF.Parsers

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
            media: :audio | :video | :unknown,
            metadata: map()
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
      media: :unknown,
      metadata: %{}
    ]
  end

  @type input_selector :: InputRef.selector()

  @spec input(non_neg_integer(), input_selector()) :: Stream.t()
  def input(index, selector) when is_integer(index) and index >= 0 do
    input_ref = %InputRef{input: index, selector: selector}

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
    name = normalize_name(name)
    %{outputs: outputs} = fetch_filter!(name)
    option_specs = filter_spec(name)

    apply_filter(name, inputs, outputs, options, option_specs)
  end

  @spec apply_filter(atom(), [Stream.t() | [Stream.t()]], [atom()], keyword(), map()) ::
          Stream.t() | Terminal.t() | [Stream.t()] | tuple()
  def apply_filter(name, inputs, outputs, options, option_specs) do
    inputs = normalize_inputs(inputs)
    validate_streams!(inputs)
    validate_options!(options, option_specs)

    output_count = output_count(outputs, options)
    output_media = output_media(outputs, output_count, inputs)

    plan = %Plan{
      id: make_ref(),
      kind: :filter,
      name: name,
      inputs: inputs,
      args: normalize_args(options),
      outputs: output_count,
      media: summarize_media(output_media)
    }

    build_result(plan, outputs, output_media)
  end

  @spec graph(keyword()) :: Graph.t()
  def graph(options) when is_list(options) do
    {exports, terminals} = normalize_roots(options)
    metadata = Keyword.get(options, :metadata, %{})
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
      settings: settings,
      metadata: metadata
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

    graph
  end

  def filter_spec(name) do
    name
    |> Help.filter()
    |> Enum.map(&Parsers.FilterSpec.parse/1)
    |> collect(%{all: [], current: nil})
    |> Enum.filter(& &1)
    |> Enum.map(&normalize_flags/1)
    |> Map.new(&{String.to_atom(&1.name), &1})
  end

  @spec build_options_doc(map()) :: String.t()
  def build_options_doc(options) do
    options
    |> Enum.map(fn {name, config} ->
      build_option_doc(name, config)
    end)
    |> Enum.join("\n")
  end

  defp build_option_doc(name, config) do
    case config[:sub] do
      nil ->
        "  * #{name} - #{config.desc}"

      flags ->
        flags =
          flags
          |> Enum.map(fn flag ->
            num = if flag.num != "", do: " (#{flag.num}) ", else: ""
            desc = if flag.desc != "", do: " - #{flag.desc}", else: ""

            "    - #{flag.enum}#{num}#{desc}"
          end)
          |> Enum.join("\n")

        """
          * #{name} - #{config.desc}
        #{flags}
        """
    end
  end

  @spec build_options_typespec(map()) :: Macro.t()
  def build_options_typespec(options) do
    quote do
      [unquote_splicing(for option <- options, do: option_typespec(option))]
    end
  end

  defp option_typespec({name, config}) do
    type =
      case config.type do
        {:array, type} ->
          quote(do: [unquote(core_type(type, config[:sub]))])

        type ->
          core_type(type, config[:sub])
      end

    quote do
      {unquote(name), unquote(type)}
    end
  end

  defp core_type(type, nil) do
    case type do
      :int -> quote(do: integer())
      :int64 -> quote(do: integer())
      :binary -> quote(do: binary())
      :boolean -> quote(do: boolean())
      :string -> quote(do: String.t())
      :float -> quote(do: float())
      :double -> quote(do: float())
      _ -> quote(do: term())
    end
  end

  defp core_type(type, sub) do
    case type do
      :int -> enum_typespec(sub)
      :flags -> quote(do: [unquote(enum_typespec(sub))])
      _ -> quote(do: term())
    end
  end

  defp enum_typespec([]), do: quote(do: term())

  defp enum_typespec(sub) do
    sub
    |> Enum.map(&String.to_atom(&1.enum))
    |> Enum.reduce(fn left, right -> {:|, [], [left, right]} end)
  end

  @option_depth 3
  @enum_depth 5

  defp collect([], acc) do
    acc.all ++ [acc.current]
  end

  defp collect([[{:depth, 2} | rest] | specs], acc) do
    [name, {:type, type}, flags, desc] = rest
    spec = %{name: name, type: type, flags: flags, desc: desc}
    %{current: current, all: all} = acc

    collect(specs, %{current: spec, all: all ++ [current]})
  end

  defp collect([[{:depth, @option_depth} | rest] | specs], acc) do
    [name, {:type, type}, flags, desc] = rest
    spec = %{name: name, type: type, flags: flags, desc: desc}
    %{current: current, all: all} = acc

    collect(specs, %{current: spec, all: all ++ [current]})
  end

  defp collect([[{:depth, @enum_depth} | rest] | specs], acc) do
    [enum, num, flags, desc] = rest
    enum_spec = %{enum: enum, num: num, flags: flags, desc: desc}
    %{current: current, all: all} = acc
    current = Map.update(current, :sub, [enum_spec], &(&1 ++ [enum_spec]))

    collect(specs, %{current: current, all: all})
  end

  defp normalize_name(name) when is_atom(name), do: name
  defp normalize_name(name) when is_binary(name), do: String.to_atom(name)

  defp fetch_filter!(name) do
    case Help.filters()[name] do
      nil -> raise ArgumentError, "unknown filter #{inspect(name)}"
      filter -> filter
    end
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
      other -> raise ArgumentError, "expected FF.Stream, got: #{inspect(other)}"
    end)
  end

  # We only validate names here. Value coercion can grow later without changing the graph model.
  defp validate_options!(options, specs) do
    Enum.each(options, fn
      {:pos, _value} -> :ok
      {key, _value} ->
        unless specs == %{} or Map.has_key?(specs, key) do
          raise ArgumentError, "#{key} is not a valid option"
        end
    end)

    :ok
  end

  defp normalize_args(options) do
    Enum.map(options, fn
      {:pos, value} -> {:pos, value}
      {key, value} -> {key, value}
    end)
  end

  defp output_count([], _options), do: 0
  defp output_count([:N], options), do: dynamic_output_count(options)
  defp output_count(outputs, _options), do: length(outputs)

  # Dynamic filters need a concrete output count once they become graph nodes.
  # Start with the common `outputs:` option and default to one output otherwise.
  defp dynamic_output_count(options) do
    case Keyword.get(options, :outputs) do
      value when is_integer(value) and value > 0 -> value
      value when is_binary(value) ->
        case Integer.parse(value) do
          {count, ""} when count > 0 -> count
          _ -> 1
        end

      _ ->
        1
    end
  end

  defp output_media([], _count, inputs) do
    [infer_input_media(inputs)]
  end

  defp output_media([:N], count, inputs) do
    List.duplicate(infer_input_media(inputs), count)
  end

  defp output_media(outputs, _count, _inputs) do
    Enum.map(outputs, &media_from_io/1)
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
        media: plan.media,
        metadata: plan.metadata
      }

      {node_id, node}
    end)
  end

  defp to_ref(%Stream{plan: plan, output: output}, id_map) do
    %Ref{node_id: Map.fetch!(id_map, plan.id), output: output}
  end

  defp selector_media(:video), do: :video
  defp selector_media(:audio), do: :audio
  defp selector_media({:video, _}), do: :video
  defp selector_media({:audio, _}), do: :audio
  defp selector_media(_), do: :unknown

  defp normalize_flags(arg), do: arg
end
