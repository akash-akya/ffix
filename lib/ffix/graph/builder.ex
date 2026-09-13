defmodule FFix.Graph.Builder do
  @moduledoc false

  alias FFix.Graph
  alias FFix.Graph.Export
  alias FFix.Graph.InputRef
  alias FFix.Graph.Node
  alias FFix.Graph.Merge
  alias FFix.Graph.Ref
  alias FFix.Graph.StreamRef
  alias FFix.Graph.Terminal
  alias FFix.Graph.Validator
  alias FFix.Value

  @type input_id :: InputRef.input_id() | atom()
  @type input_selector :: InputRef.selector()

  @spec input(input_id(), input_selector()) :: StreamRef.t()
  def input(index, selector) do
    input_ref = InputRef.new(index, selector)
    selector = Validator.selector!(input_ref.selector)

    node = %Node{
      id: make_ref(),
      kind: :input,
      name: :input,
      input_ref: input_ref,
      output_media: [selector_media(selector)]
    }

    graph = %Graph{id: make_ref(), nodes: %{node.id => node}, order: [node.id]}

    %StreamRef{
      graph: graph,
      ref: %Ref{node_id: node.id, output: 0},
      media: selector_media(selector)
    }
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
    inputs =
      if is_struct(inputs, StreamRef) do
        [inputs]
      else
        inputs
      end

    validate_streams!(inputs)
    name = Validator.filter_name!(name)
    output_media = normalize_output_shape!(output_media)
    args = normalize_generic_args!(options)
    build_filter(name, inputs, args, output_media)
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
        Map.has_key?(FFix.Metadata.filters(), name) ->
          FFix.Filter.Shape.resolve(name, :outputs, options)

        outputs == [:N] ->
          {:unresolved, "#{name} has no supported output-shape policy"}

        true ->
          {:ok, Enum.map(outputs, &media_from_io/1)}
      end

    case shape do
      {:ok, output_media} ->
        build_filter(name, inputs, args, output_media)

      {:unresolved, reason} ->
        raise ArgumentError,
              "unresolved filter output shape: #{reason}; use FFix.Filter.filter/4 with explicit output media"
    end
  end

  defp build_filter(name, inputs, args, output_media) do
    graph =
      case inputs do
        [stream] ->
          # Extending one snapshot needs no merge. Full validation still runs
          # when the graph is materialized, including any hand-edited ancestors.
          %{stream.graph | id: make_ref(), exports: []}

        _inputs ->
          Merge.merge(Enum.map(inputs, & &1.graph))
      end

    node = %Node{
      id: make_ref(),
      kind: :filter,
      name: name,
      inputs: Enum.map(inputs, & &1.ref),
      args: args,
      output_media: output_media
    }

    graph = %{graph | nodes: Map.put(graph.nodes, node.id, node), order: graph.order ++ [node.id]}

    case output_media do
      [] ->
        graph = %{graph | terminals: graph.terminals ++ [node.id]}
        %Terminal{graph: graph, node_id: node.id}

      [media] ->
        %StreamRef{graph: graph, ref: %Ref{node_id: node.id, output: 0}, media: media}

      media ->
        Enum.with_index(media, fn type, output ->
          %StreamRef{graph: graph, ref: %Ref{node_id: node.id, output: output}, media: type}
        end)
    end
  end

  @spec graph(keyword()) :: Graph.t()
  def graph(options) when is_list(options) do
    validate_graph_keys!(options)
    {exports, terminals} = normalize_roots(options)
    settings = Validator.settings!(Keyword.get(options, :settings, []))

    streams = Enum.map(exports, fn {_name, stream} -> stream end)
    graphs = Enum.map(streams ++ terminals, & &1.graph)
    graph = Merge.merge(graphs, settings)

    graph_exports =
      Enum.map(exports, fn {name, stream} ->
        %Export{graph_id: graph.id, name: name, ref: stream.ref, media: stream.media}
      end)

    %{graph | exports: graph_exports}
  end

  defp validate_named_inputs!(name, inputs, signature) do
    unless length(inputs) == length(signature) do
      raise ArgumentError, "invalid input count for #{name}"
    end

    Enum.zip(inputs, signature)
    |> Enum.each(fn
      {streams, :N} when is_list(streams) ->
        validate_streams!(streams)

      {%StreamRef{media: media}, expected} when expected in [:A, :V] ->
        expected_media = media_from_io(expected)

        if media not in [:unknown, expected_media] do
          raise ArgumentError, "#{name} expects #{expected_media} input, got: #{media}"
        end

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
      %StreamRef{} = stream ->
        StreamRef.node!(stream)

      %FFix.Selection{} ->
        raise ArgumentError, "filter inputs require one stream, not an unresolved selection"

      other ->
        raise ArgumentError, "expected FFix.Graph.StreamRef, got: #{inspect(other)}"
    end)
  end

  defp validate_streams!(other) do
    raise ArgumentError,
          "filter inputs must be a stream reference or a flat list, got: #{inspect(other)}"
  end

  defp normalize_output_shape!(media) when is_list(media),
    do: Enum.map(media, &Validator.media!/1)

  defp normalize_output_shape!(other) do
    raise ArgumentError, "filter output media must be an ordered list, got: #{inspect(other)}"
  end

  defp normalize_generic_args!(options) when is_list(options) do
    {args, _names} =
      Enum.map_reduce(options, MapSet.new(), fn option, names ->
        case option do
          {:pos, value} ->
            {{:pos, Validator.value!(value)}, names}

          {key, value} when is_atom(key) or is_binary(key) ->
            key = Validator.option_name!(key)

            if MapSet.member?(names, key) do
              raise ArgumentError, "duplicate filter option: #{inspect(key)}"
            end

            {{key, Validator.value!(value)}, MapSet.put(names, key)}

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
    Enum.find_value(specs, fn {name, spec} ->
      if to_string(name) == to_string(key) do
        spec
      end
    end)
  end

  defp validate_named_value!(values) when is_list(values),
    do: Enum.each(values, &validate_named_value!/1)

  defp validate_named_value!(value), do: Validator.value!(value)

  defp normalize_args(options, specs) do
    Enum.map(options, fn
      {:pos, value} -> {:pos, Value.normalize(value, nil)}
      {key, value} -> {key, Value.normalize(value, option_spec(specs, key))}
    end)
  end

  defp media_from_io(:A), do: :audio
  defp media_from_io(:V), do: :video
  defp media_from_io(_), do: :unknown

  defp validate_graph_keys!(options) do
    unless Keyword.keyword?(options) do
      raise ArgumentError, "graph options must be a keyword list"
    end

    keys = Keyword.keys(options)

    if length(keys) != length(Enum.uniq(keys)) do
      raise ArgumentError, "duplicate graph option; specify each root collection once"
    end

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
      {_name, %StreamRef{} = stream} -> StreamRef.node!(stream)
      other -> raise ArgumentError, "invalid graph export: #{inspect(other)}"
    end)
  end

  defp validate_terminals!(terminals) do
    unless is_list(terminals) do
      raise ArgumentError, "graph terminals must be an ordered list"
    end

    Enum.each(terminals, fn
      %Terminal{} = terminal -> Terminal.validate!(terminal)
      other -> raise ArgumentError, "invalid graph terminal: #{inspect(other)}"
    end)
  end

  defp selector_media(selector), do: InputRef.media(selector)
end
