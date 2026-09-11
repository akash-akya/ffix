defmodule FFix.Graph.Builder do
  @moduledoc false

  alias FFix.Graph
  alias FFix.Graph.Export
  alias FFix.Graph.InputRef
  alias FFix.Graph.Node
  alias FFix.Graph.Ref
  alias FFix.Graph.StreamRef
  alias FFix.Graph.Terminal
  alias FFix.Value

  defmodule Plan do
    @moduledoc false

    @type t :: %__MODULE__{
            id: reference(),
            kind: :input | :filter,
            name: atom() | String.t(),
            instance: String.t() | atom() | nil,
            input_ref: InputRef.t() | nil,
            inputs: [StreamRef.t()],
            args: [Node.arg()],
            outputs: non_neg_integer(),
            output_media: [StreamRef.media()],
            media: StreamRef.media()
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
      output_media: [:unknown],
      media: :unknown
    ]
  end

  @type input_id :: InputRef.input_id() | atom()
  @type input_selector :: InputRef.selector()

  @spec input(input_id(), input_selector()) :: StreamRef.t()
  def input(index, selector) do
    input_ref = InputRef.new(index, selector)
    selector = input_ref.selector

    plan = %Plan{
      id: make_ref(),
      kind: :input,
      name: :input,
      input_ref: input_ref,
      outputs: 1,
      output_media: [selector_media(selector)],
      media: selector_media(selector)
    }

    %StreamRef{plan: plan, output: 0, media: plan.media}
  end

  @spec input_raw(String.t()) :: StreamRef.t()
  def input_raw(spec) when is_binary(spec) do
    case Regex.run(~r/^(\d+):(.*)$/, spec) do
      [_, input, selector] ->
        input(String.to_integer(input), {:raw, selector})

      _ ->
        raise ArgumentError, "input_raw/1 expects a stream spec like \"0:v\""
    end
  end

  @type output_media :: :audio | :video | :unknown

  @spec filter(StreamRef.t() | [StreamRef.t()], atom() | String.t(), [output_media()], list()) ::
          StreamRef.t() | Terminal.t() | [StreamRef.t()]
  def filter(inputs, name, output_media, options) do
    inputs = if is_struct(inputs, StreamRef), do: [inputs], else: inputs
    validate_streams!(inputs)
    name = normalize_filter_name!(name)
    output_media = normalize_output_shape!(output_media)
    args = normalize_generic_args!(options)
    plan = filter_plan(name, inputs, args, output_media)

    case output_media do
      [] -> %Terminal{plan: plan, media: infer_input_media(inputs)}
      media -> build_shaped_result(plan, media)
    end
  end

  @spec apply_filter(
          atom(),
          [StreamRef.t() | [StreamRef.t()]],
          [atom()],
          [atom()],
          keyword(),
          map()
        ) ::
          StreamRef.t() | Terminal.t() | [StreamRef.t()]
  def apply_filter(name, inputs, input_signature, outputs, options, option_specs) do
    validate_named_inputs!(name, inputs, input_signature)
    inputs = normalize_inputs(inputs)
    validate_streams!(inputs)
    validate_options!(options, option_specs)
    args = normalize_args(options, option_specs)

    shape =
      cond do
        Map.has_key?(FFix.Filter.Metadata.filters(), name) ->
          FFix.Filter.Shape.resolve(name, :outputs, options)

        outputs == [:N] ->
          {:unresolved, "#{name} has no supported output-shape policy"}

        true ->
          {:ok, Enum.map(outputs, &media_from_io/1)}
      end

    case shape do
      {:ok, output_media} ->
        plan = filter_plan(name, inputs, args, output_media)
        build_result(plan, output_media)

      {:unresolved, reason} ->
        raise ArgumentError,
              "unresolved filter output shape: #{reason}; use FFix.Filter.filter/4 with explicit output media"
    end
  end

  @doc false
  def graph_roots(%Graph{} = graph) do
    validate_graph!(graph, allow_unused: true)

    streams =
      Enum.reduce(graph.order, %{}, fn node_id, streams ->
        node = Map.fetch!(graph.nodes, node_id)

        result =
          case node do
            %Node{kind: :input, input_ref: %{binding: %StreamRef{} = binding}} ->
              binding

            %Node{} ->
              plan = %Plan{
                id: node.identity,
                kind: node.kind,
                name: node.name,
                instance: node.instance,
                input_ref: node.input_ref,
                inputs: Enum.map(node.inputs, &graph_stream!(&1, streams)),
                args: node.args,
                outputs: node.outputs,
                output_media: node.output_media,
                media: node.media
              }

              build_result(plan, node.output_media)
          end

        Map.put(streams, node_id, result)
      end)

    exports = Enum.map(graph.exports, &graph_stream!(&1.ref, streams))
    terminals = Enum.map(graph.terminals, &Map.fetch!(streams, &1))

    roots =
      Enum.map(graph.order, fn node_id ->
        case Map.fetch!(streams, node_id) do
          outputs when is_list(outputs) -> hd(outputs)
          root -> root
        end
      end)

    context = %{id: graph.id, roots: roots, settings: graph.settings}
    {Enum.map(exports, &%{&1 | context: context}), Enum.map(terminals, &%{&1 | context: context})}
  end

  defp graph_stream!(%Ref{node_id: node_id, output: output}, streams) do
    case Map.fetch!(streams, node_id) do
      %StreamRef{} = stream when output == 0 -> stream
      streams when is_list(streams) -> Enum.fetch!(streams, output)
    end
  end

  defp filter_plan(name, inputs, args, output_media) do
    %Plan{
      id: make_ref(),
      kind: :filter,
      name: name,
      inputs: inputs,
      args: args,
      outputs: length(output_media),
      output_media: output_media,
      media: summarize_media(output_media)
    }
  end

  @spec graph(keyword()) :: Graph.t()
  def graph(options) when is_list(options) do
    validate_graph_keys!(options)
    {exports, terminals} = normalize_roots(options)
    settings = normalize_settings(Keyword.get(options, :settings, []))

    {plans, contexts} = collect_plans(exports, terminals)
    settings = merge_settings!([settings | Enum.map(contexts, & &1.settings)])
    {id_map, order} = assign_ids(plans)
    nodes = materialize_nodes(plans, id_map)

    graph_id = make_ref()

    graph_exports =
      Enum.map(exports, fn {name, %StreamRef{plan: plan, output: output, media: media}} ->
        %Export{
          graph_id: graph_id,
          name: name,
          ref: %Ref{node_id: id_map[plan.id], output: output},
          media: media
        }
      end)

    graph_terminals =
      for %Plan{kind: :filter, outputs: 0, id: id} <- plans, do: Map.fetch!(id_map, id)

    %Graph{
      id: graph_id,
      nodes: nodes,
      order: order,
      exports: graph_exports,
      terminals: graph_terminals,
      settings: settings
    }
  end

  @spec validate_graph!(Graph.t(), keyword()) :: Graph.t()
  def validate_graph!(%Graph{} = graph, options \\ []) do
    unless is_reference(graph.id) and is_map(graph.nodes) and is_list(graph.order) and
             is_list(graph.exports) and is_list(graph.terminals) do
      raise ArgumentError, "invalid graph structure"
    end

    unless Enum.uniq(graph.order) == graph.order and
             MapSet.new(graph.order) == MapSet.new(Map.keys(graph.nodes)) do
      raise ArgumentError, "graph order must contain every node exactly once"
    end

    normalize_settings(graph.settings)

    identities = Enum.map(graph.order, &Map.get(graph.nodes[&1], :identity))

    unless Enum.all?(identities, &is_reference/1) and Enum.uniq(identities) == identities,
      do: raise(ArgumentError, "graph nodes must have distinct identities")

    Enum.reduce(graph.order, %{}, fn node_id, preceding ->
      node = Map.fetch!(graph.nodes, node_id)
      validate_node!(node, node_id)
      Enum.each(node.inputs, &validate_ref!(&1, preceding, "input"))
      validate_node_inputs!(node, preceding)
      Map.put(preceding, node_id, node)
    end)

    Enum.reduce(graph.exports, MapSet.new(), fn export, names ->
      unless match?(%Export{graph_id: id} when id == graph.id, export) do
        raise ArgumentError, "graph export belongs to a different graph"
      end

      validate_ref!(export.ref, graph.nodes, "export")
      node = Map.fetch!(graph.nodes, export.ref.node_id)

      unless export.media == Enum.at(node.output_media, export.ref.output) do
        raise ArgumentError, "graph export media does not match its output pad"
      end

      name = export.name

      unless is_nil(name) or (is_atom(name) and name not in [true, false]) or
               (is_binary(name) and name != "") do
        raise ArgumentError, "invalid graph export name: #{inspect(name)}"
      end

      key = if name != nil, do: to_string(name)

      if key != nil and MapSet.member?(names, key),
        do: raise(ArgumentError, "duplicate graph export name: #{inspect(name)}")

      MapSet.put(names, key)
    end)

    sinks =
      Enum.filter(
        graph.order,
        &(graph.nodes[&1].kind == :filter and graph.nodes[&1].outputs == 0)
      )

    unless Enum.uniq(graph.terminals) == graph.terminals and
             MapSet.new(sinks) == MapSet.new(graph.terminals) do
      raise ArgumentError, "graph terminals must contain every sink exactly once"
    end

    validate_connected_outputs!(graph, Keyword.get(options, :allow_unused, false))
    graph
  end

  defp validate_node!(%Node{id: node_id} = node, node_id)
       when is_integer(node_id) and node_id > 0 do
    unless node.kind in [:input, :filter] and is_list(node.inputs) and
             is_integer(node.outputs) and node.outputs >= 0 and is_list(node.output_media) and
             length(node.output_media) == node.outputs do
      raise ArgumentError, "invalid output shape for graph node #{node_id}"
    end

    if node.kind == :input do
      unless node.inputs == [] and node.outputs == 1 and is_struct(node.input_ref, InputRef),
        do: raise(ArgumentError, "invalid graph input node #{node_id}")

      InputRef.normalize_input_id!(node.input_ref.input)
      selector = InputRef.normalize_selector!(node.input_ref.selector)

      unless node.output_media == [selector_media(selector)],
        do: raise(ArgumentError, "graph input media does not match its selector")
    else
      Enum.each(node.output_media, &normalize_output_media!/1)
      normalize_filter_name!(node.name)
      if node.instance != nil, do: normalize_filter_name!(node.instance)
      validate_args!(node.args)
    end
  end

  defp validate_node!(_node, node_id),
    do: raise(ArgumentError, "invalid graph node #{inspect(node_id)}")

  defp validate_node_inputs!(%Node{kind: :filter, name: name} = node, nodes) when is_atom(name) do
    if Map.has_key?(FFix.Filter.Metadata.filters(), name) do
      case FFix.Filter.Shape.resolve(name, :outputs, node.args) do
        {:ok, media} when media != node.output_media ->
          raise ArgumentError, "invalid output media/count for #{name}"

        _ ->
          :ok
      end

      expected =
        case FFix.Filter.Shape.resolve(name, :inputs, node.args) do
          {:ok, media} ->
            unless length(media) == length(node.inputs),
              do: raise(ArgumentError, "invalid input count for #{name}")

            media

          {:unresolved, _reason} ->
            FFix.Filter.Metadata.filter!(name).inputs
            |> Enum.filter(&(&1 in [:A, :V]))
            |> Enum.map(&media_from_io/1)
        end

      if length(node.inputs) < length(expected),
        do: raise(ArgumentError, "missing fixed input pads for #{name}")

      if length(node.inputs) < length(expected),
        do: raise(ArgumentError, "missing fixed inputs for #{name}")

      Enum.zip(node.inputs, expected)
      |> Enum.each(fn {ref, media} ->
        actual = Enum.fetch!(nodes[ref.node_id].output_media, ref.output)

        if actual not in [:unknown, media],
          do: raise(ArgumentError, "#{name} expects #{media} input, got: #{actual}")
      end)
    end
  end

  defp validate_node_inputs!(_node, _nodes), do: :ok

  defp validate_ref!(%Ref{node_id: node_id, output: output}, nodes, context) do
    case Map.get(nodes, node_id) do
      %Node{outputs: outputs} when is_integer(output) and output >= 0 and output < outputs ->
        :ok

      _ ->
        raise ArgumentError,
              "invalid #{context} ref #{inspect({node_id, output})}; referenced pads must exist and precede their consumers"
    end
  end

  defp validate_ref!(ref, _nodes, context),
    do: raise(ArgumentError, "invalid #{context} ref: #{inspect(ref)}")

  defp validate_named_inputs!(name, inputs, signature) do
    unless length(inputs) == length(signature),
      do: raise(ArgumentError, "invalid input count for #{name}")

    Enum.zip(inputs, signature)
    |> Enum.each(fn
      {streams, :N} when is_list(streams) ->
        validate_streams!(streams)

      {%StreamRef{media: media}, expected} when expected in [:A, :V] ->
        expected_media = media_from_io(expected)

        if media not in [:unknown, expected_media],
          do: raise(ArgumentError, "#{name} expects #{expected_media} input, got: #{media}")

      {other, _expected} ->
        raise ArgumentError,
              "invalid input for #{name}: #{inspect(other)}; pass one stream per fixed input pad"
    end)
  end

  defp normalize_inputs(inputs) do
    Enum.flat_map(inputs, fn
      %StreamRef{} = stream ->
        [stream]

      streams when is_list(streams) ->
        streams

      other ->
        raise ArgumentError,
              "expected a stream reference or ordered input list, got: #{inspect(other)}"
    end)
  end

  defp validate_streams!(inputs) when is_list(inputs) do
    Enum.each(inputs, fn
      %StreamRef{plan: %{kind: :input, input_ref: %{selector: selector}}} ->
        if selector == :all or match?({_media, :all}, selector),
          do:
            raise(ArgumentError, "filter inputs require one stream, not an all-stream selection")

      %StreamRef{} ->
        :ok

      other ->
        raise ArgumentError, "expected FFix.Graph.StreamRef, got: #{inspect(other)}"
    end)
  end

  defp validate_streams!(other) do
    raise ArgumentError,
          "filter inputs must be a stream reference or a flat list, got: #{inspect(other)}"
  end

  defp normalize_filter_name!(name) when is_atom(name) and name not in [nil, true, false],
    do: normalize_filter_name!(Atom.to_string(name))

  defp normalize_filter_name!(name) do
    if is_binary(name) and String.match?(name, ~r/\A[a-zA-Z0-9_]+\z/) do
      name
    else
      raise ArgumentError, "filter name must be an identifier, got: #{inspect(name)}"
    end
  end

  defp normalize_output_shape!(media) when is_list(media),
    do: Enum.map(media, &normalize_output_media!/1)

  defp normalize_output_shape!(other) do
    raise ArgumentError, "filter output media must be an ordered list, got: #{inspect(other)}"
  end

  defp normalize_generic_args!(options) when is_list(options) do
    {args, _names} =
      Enum.map_reduce(options, MapSet.new(), fn option, names ->
        case option do
          {:pos, value} ->
            {{:pos, normalize_generic_value!(value)}, names}

          {key, value} when is_atom(key) or is_binary(key) ->
            key = normalize_option_name!(key)

            if MapSet.member?(names, key) do
              raise ArgumentError, "duplicate filter option: #{inspect(key)}"
            end

            {{key, normalize_generic_value!(value)}, MapSet.put(names, key)}

          other ->
            raise ArgumentError,
                  "filter options must be ordered name/value pairs, got: #{inspect(other)}"
        end
      end)

    args
  end

  defp normalize_generic_args!(other) do
    raise ArgumentError, "filter options must be an ordered list, got: #{inspect(other)}"
  end

  defp normalize_option_name!(key) do
    name = to_string(key)

    if key not in [nil, true, false] and String.match?(name, ~r{\A/?[a-zA-Z0-9_][a-zA-Z0-9_-]*\z}) do
      name
    else
      raise ArgumentError, "filter option name must be an unscoped name, got: #{inspect(key)}"
    end
  end

  defp normalize_generic_value!(value) when is_binary(value) do
    if String.contains?(value, <<0>>) do
      raise ArgumentError, "filter option values cannot contain NUL"
    end

    value
  end

  defp normalize_generic_value!(value) when is_number(value) or is_boolean(value), do: value

  defp normalize_generic_value!(value) when is_atom(value) and not is_nil(value),
    do: Atom.to_string(value)

  defp normalize_generic_value!(other) do
    raise ArgumentError,
          "filter option values must be scalars or expressions; use strings for compound values, got: #{inspect(other)}"
  end

  # Keep value normalization permissive so raw ffmpeg strings remain an escape hatch.
  defp validate_options!(options, specs) do
    {_special, options} = FFix.Options.split!(options, [])

    Enum.each(options, fn {key, value} ->
      if key != :pos and option_spec(specs, key) == nil do
        raise ArgumentError, "#{key} is not a valid option"
      end

      validate_named_value!(value)
    end)
  end

  defp option_spec(specs, key) do
    Enum.find_value(specs, fn {name, spec} -> if to_string(name) == to_string(key), do: spec end)
  end

  defp validate_named_value!(values) when is_list(values),
    do: Enum.each(values, &validate_named_value!/1)

  defp validate_named_value!(value), do: normalize_generic_value!(value)

  defp normalize_args(options, specs) do
    Enum.map(options, fn
      {:pos, value} -> {:pos, Value.normalize(value, nil)}
      {key, value} -> {key, Value.normalize(value, option_spec(specs, key))}
    end)
  end

  defp summarize_media(media) do
    case Enum.uniq(media) do
      [single] -> single
      _ -> :unknown
    end
  end

  defp infer_input_media([%StreamRef{media: media} | _]), do: media
  defp infer_input_media(_inputs), do: :unknown

  defp media_from_io(:A), do: :audio
  defp media_from_io(:V), do: :video
  defp media_from_io(_), do: :unknown

  defp build_result(plan, []) do
    %Terminal{plan: plan, media: infer_input_media(plan.inputs)}
  end

  defp build_result(plan, media), do: build_shaped_result(plan, media)

  defp build_shaped_result(plan, [media]) do
    %StreamRef{plan: plan, output: 0, media: media}
  end

  defp build_shaped_result(plan, output_media) do
    Enum.with_index(output_media, fn media, output ->
      %StreamRef{plan: plan, output: output, media: media}
    end)
  end

  defp validate_graph_keys!(options) do
    unless Keyword.keyword?(options),
      do: raise(ArgumentError, "graph options must be a keyword list")

    keys = Keyword.keys(options)

    if length(keys) != length(Enum.uniq(keys)),
      do: raise(ArgumentError, "duplicate graph option; specify each root collection once")

    unknown = keys -- [:output, :outputs, :terminals, :settings]

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
      {name, %StreamRef{} = stream} when is_atom(name) or is_binary(name) -> {name, stream}
      %StreamRef{} = stream -> {nil, stream}
      other -> raise ArgumentError, "invalid graph export: #{inspect(other)}"
    end)
  end

  defp normalize_exports(_outputs),
    do: raise(ArgumentError, "graph exports must be an ordered list")

  defp validate_exports!(exports) do
    Enum.each(exports, fn
      {_name, %StreamRef{}} -> :ok
      other -> raise ArgumentError, "invalid graph export: #{inspect(other)}"
    end)
  end

  defp validate_terminals!(terminals) do
    unless is_list(terminals), do: raise(ArgumentError, "graph terminals must be an ordered list")

    Enum.each(terminals, fn
      %Terminal{} -> :ok
      other -> raise ArgumentError, "invalid graph terminal: #{inspect(other)}"
    end)
  end

  defp normalize_output_media!(:audio), do: :audio
  defp normalize_output_media!(:video), do: :video
  defp normalize_output_media!(:unknown), do: :unknown

  defp normalize_output_media!(media) do
    raise ArgumentError,
          "output media must be :audio, :video, or :unknown, got: #{inspect(media)}"
  end

  defp validate_connected_outputs!(graph, allow_unused) do
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
      |> Enum.frequencies()

    Enum.each(graph.order, fn node_id ->
      case Map.fetch!(graph.nodes, node_id) do
        %Node{kind: :filter, outputs: outputs} when outputs > 0 ->
          Enum.each(0..(outputs - 1), fn output ->
            case Map.get(used_outputs, {node_id, output}, 0) do
              0 when allow_unused ->
                :ok

              0 ->
                raise ArgumentError,
                      "unconnected filter output #{inspect({node_id, output})}; every produced output must be consumed or exported"

              1 ->
                :ok

              count ->
                raise ArgumentError,
                      "filter output #{inspect({node_id, output})} is used #{count} times; use split/asplit for multiple consumers"
            end
          end)

        _node ->
          :ok
      end
    end)
  end

  defp validate_args!(args) when is_list(args) do
    Enum.each(args, fn
      {:pos, value} ->
        validate_argument_value!(value)

      {key, value} when is_atom(key) or is_binary(key) ->
        normalize_option_name!(key)
        validate_argument_value!(value)

      other ->
        raise ArgumentError, "invalid filter argument: #{inspect(other)}"
    end)
  end

  defp validate_args!(_args), do: raise(ArgumentError, "filter arguments must be an ordered list")

  defp validate_argument_value!(value) when is_list(value),
    do: Enum.each(value, &normalize_generic_value!/1)

  defp validate_argument_value!(value), do: normalize_generic_value!(value)

  defp normalize_settings(settings) when is_list(settings) do
    Enum.reduce(settings, MapSet.new(), fn
      {key, value}, names when is_atom(key) or is_binary(key) ->
        name = normalize_filter_name!(key)
        if name != "sws_flags", do: raise(ArgumentError, "unsupported graph setting: #{name}")

        if MapSet.member?(names, name),
          do: raise(ArgumentError, "duplicate graph setting: #{name}")

        if is_list(value),
          do: Enum.each(value, &normalize_generic_value!/1),
          else: normalize_generic_value!(value)

        MapSet.put(names, name)

      other, _names ->
        raise ArgumentError, "invalid graph setting: #{inspect(other)}"
    end)

    settings
  end

  defp normalize_settings(_settings),
    do: raise(ArgumentError, "graph settings must be an ordered list")

  defp merge_settings!(collections) do
    {settings, _seen} =
      Enum.reduce(collections, {[], %{}}, fn collection, acc ->
        Enum.reduce(normalize_settings(collection), acc, fn {key, value}, {settings, seen} ->
          name = to_string(key)

          case Map.fetch(seen, name) do
            {:ok, ^value} -> {settings, seen}
            {:ok, _} -> raise ArgumentError, "conflicting graph setting: #{name}"
            :error -> {settings ++ [{key, value}], Map.put(seen, name, value)}
          end
        end)
      end)

    settings
  end

  defp collect_plans(exports, terminals) do
    roots = Enum.map(exports, fn {_name, stream} -> stream end) ++ terminals

    state =
      Enum.reduce(roots, %{seen: %{}, plans: [], contexts: %{}, context_order: []}, &visit_root/2)

    {Enum.reverse(state.plans), Enum.map(state.context_order, &Map.fetch!(state.contexts, &1))}
  end

  defp visit_root(root, state) do
    plan = plan_of(root)

    state =
      case root.context do
        nil ->
          state

        %{id: id, roots: roots, settings: settings} = context
        when is_reference(id) and is_list(roots) ->
          normalize_settings(settings)

          case Map.fetch(state.contexts, id) do
            {:ok, ^context} ->
              state

            {:ok, _} ->
              raise ArgumentError, "conflicting definitions for the same graph identity"

            :error ->
              state = %{
                state
                | contexts: Map.put(state.contexts, id, context),
                  context_order: state.context_order ++ [id]
              }

              Enum.reduce(roots, state, &visit_root/2)
          end

        other ->
          raise ArgumentError, "invalid graph context: #{inspect(other)}"
      end

    visit_plan(plan, state)
  end

  defp visit_plan(%Plan{id: id} = plan, state) when is_reference(id) do
    case Map.fetch(state.seen, id) do
      {:ok, ^plan} ->
        state

      {:ok, previous} ->
        unless plan_definition(previous) == plan_definition(plan),
          do: raise(ArgumentError, "conflicting definitions for the same filter/input identity")

        state = %{state | seen: Map.put(state.seen, id, plan)}
        Enum.reduce(plan.inputs, state, &visit_root/2)

      :error ->
        state = %{state | seen: Map.put(state.seen, id, plan)}
        state = Enum.reduce(plan.inputs, state, &visit_root/2)
        %{state | plans: [plan | state.plans]}
    end
  end

  defp visit_plan(plan, _acc),
    do: raise(ArgumentError, "invalid filter/input plan: #{inspect(plan)}")

  defp plan_definition(plan) do
    inputs = Enum.map(plan.inputs, fn stream -> {stream.plan.id, stream.output, stream.media} end)
    plan |> Map.from_struct() |> Map.put(:inputs, inputs)
  end

  defp plan_of(%StreamRef{plan: %Plan{} = plan, output: output, media: media}) do
    unless is_integer(output) and output >= 0 and output < plan.outputs and
             Enum.at(plan.output_media, output) == media do
      raise ArgumentError, "invalid stream output pad #{inspect(output)}"
    end

    plan
  end

  defp plan_of(%Terminal{plan: %Plan{kind: :filter, outputs: 0} = plan}), do: plan

  defp plan_of(other),
    do: raise(ArgumentError, "invalid graph root or filter input: #{inspect(other)}")

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
        identity: plan.id,
        kind: plan.kind,
        name: plan.name,
        instance: plan.instance,
        input_ref: plan.input_ref,
        inputs: Enum.map(plan.inputs, &to_ref(&1, id_map)),
        args: plan.args,
        outputs: plan.outputs,
        output_media: plan.output_media,
        media: plan.media
      }

      {node_id, node}
    end)
  end

  defp to_ref(%StreamRef{plan: plan, output: output}, id_map) do
    %Ref{node_id: Map.fetch!(id_map, plan.id), output: output}
  end

  defp selector_media(selector), do: InputRef.media(selector)
end
