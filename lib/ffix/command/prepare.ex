defmodule FFix.Command.Prepare do
  @moduledoc false

  alias FFix.Command
  alias FFix.Command.{Encoding, Input, Output}
  alias FFix.Graph
  alias FFix.Graph.{Export, InputRef, Ref, StreamRef, Validator}
  alias FFix.Options
  alias FFix.Selection

  @typedoc "The boolean marks an optional input selection."
  @type source :: {:input, InputRef.t(), boolean()} | {:filter, Ref.t()}

  @typedoc "`streams` is populated only for option callbacks."
  @type output :: %{
          target: Output.target(),
          sources: [source()],
          encodings: Encoding.plan(),
          muxer: FFix.Muxer.t() | nil,
          options: [Output.option()],
          streams: Command.streams() | nil
        }

  @type t :: %{
          global_options: [Command.option()],
          inputs: [Input.t()],
          graph: Graph.t() | nil,
          outputs: [output()]
        }

  @doc "Validates without evaluating callbacks."
  @spec command!(Command.t()) :: t()
  def command!(%Command{} = command) do
    Options.validate_cli!(command.global_options)
    inputs = index_inputs!(command.inputs)

    unless is_list(command.outputs) and command.outputs != [] do
      raise ArgumentError, "command requires at least one output"
    end

    outputs =
      Enum.map(command.outputs, fn output ->
        Output.validate!(output)
        {output, Output.callbacks?(output)}
      end)

    configured? =
      Enum.any?(outputs, fn {output, callbacks?} ->
        callbacks? or Enum.any?(output.mappings, &(&1.encoding != nil))
      end)

    if configured? do
      Options.reject_conflicts!(command.global_options, :configured_mappings)
      Enum.each(command.inputs, &Options.reject_conflicts!(&1.options, :configured_mappings))
    end

    graph = resolve_graph!(command.graph, inputs)
    outputs = Enum.map(outputs, &prepare_output!(&1, graph, inputs))
    validate_export_mappings!(graph, outputs)

    %{
      global_options: command.global_options,
      inputs: command.inputs,
      graph: graph,
      outputs: outputs
    }
  end

  @doc "Evaluates and validates option callbacks."
  @spec resolve_options!(t()) :: t()
  def resolve_options!(prepared) do
    outputs =
      Enum.map(prepared.outputs, fn output ->
        if output.streams == nil do
          output
        else
          encodings =
            Enum.map(output.encodings, fn {encoding, selector} ->
              {resolve_component!(encoding, output.streams), selector}
            end)

          options = Options.resolve!(output.options, output.streams)
          Options.validate_cli!(options)

          %{
            output
            | encodings: encodings,
              muxer: resolve_component!(output.muxer, output.streams),
              options: options
          }
        end
      end)

    %{prepared | outputs: outputs}
  end

  defp resolve_component!(unconfigured, _streams) when unconfigured in [nil, :copy],
    do: unconfigured

  defp resolve_component!(component, streams) do
    options = Options.resolve!(component.options, streams)
    Options.validate_component!(%{component | options: options})
  end

  defp index_inputs!(inputs) do
    unless is_list(inputs) do
      raise ArgumentError, "command inputs must be a list"
    end

    inputs
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {input, index}, lookup ->
      Input.validate!(input)
      entry = {index, input}
      lookup = Map.put(lookup, index, entry)

      cond do
        input.id == nil ->
          lookup

        Map.has_key?(lookup, input.id) ->
          raise ArgumentError, "duplicate command input declaration"

        true ->
          Map.put(lookup, input.id, entry)
      end
    end)
  end

  defp resolve_input!(%InputRef{} = reference, inputs) do
    case Map.fetch(inputs, reference.input) do
      {:ok, {index, declaration}} ->
        if reference.declaration != nil and reference.declaration != declaration do
          raise ArgumentError, "conflicting input snapshots for #{inspect(reference.input)}"
        end

        %{reference | input: index}

      :error ->
        raise ArgumentError, "input #{inspect(reference.input)} is not declared in the command"
    end
  end

  defp resolve_graph!(nil, _inputs), do: nil

  defp resolve_graph!(%Graph{} = graph, inputs) do
    Validator.graph!(graph)

    if graph.settings != [] and
         not Enum.any?(graph.nodes, fn {_id, node} -> node.kind == :filter end) do
      raise ArgumentError, "graph settings require filter nodes"
    end

    nodes =
      Map.new(graph.nodes, fn
        {node_id, %{kind: :input} = node} ->
          {node_id, %{node | input_ref: resolve_input!(node.input_ref, inputs)}}

        entry ->
          entry
      end)

    %{graph | nodes: nodes}
  end

  defp resolve_graph!(other, _inputs) do
    raise ArgumentError, "invalid command graph: #{inspect(other)}"
  end

  defp prepare_output!({output, callbacks?}, graph, inputs) do
    mappings =
      Enum.map(output.mappings, fn mapping ->
        {source, media, single?} = classify_source!(mapping.source, graph, inputs)

        if mapping.encoding == :copy and match?({:filter, _ref}, source) do
          raise ArgumentError, "cannot copy a filtered source; use an encoder"
        end

        %{
          source: source,
          media: media,
          single: single?,
          name: mapping.name,
          encoding: mapping.encoding
        }
      end)

    encodings = Encoding.plan!(mappings)

    streams =
      if callbacks? do
        Options.reject_conflicts!(output.options, :callbacks)
        output_streams!(mappings)
      end

    %{
      target: output.target,
      sources: Enum.map(mappings, & &1.source),
      encodings: encodings,
      muxer: output.muxer,
      options: output.options,
      streams: streams
    }
  end

  defp classify_source!(%Selection{} = selection, _graph, inputs) do
    Selection.validate!(selection)
    reference = resolve_input!(selection.input_ref, inputs)
    {{:input, reference, selection.optional}, Selection.media(selection), false}
  end

  defp classify_source!(%StreamRef{} = stream, _graph, inputs) do
    node = StreamRef.node!(stream)
    Validator.graph!(stream.graph, allow_unused: true)

    unless node.kind == :input and map_size(stream.graph.nodes) == 1 and
             stream.graph.settings == [] do
      raise ArgumentError,
            "graph references require FFix.command/2 or canonical graph.exports handles with an explicit graph"
    end

    reference = resolve_input!(node.input_ref, inputs)
    single_input!(reference, stream.media)
  end

  defp classify_source!(%Export{} = export, nil, _inputs) do
    raise ArgumentError, "graph export #{inspect(export.name || export.ref)} requires a graph"
  end

  defp classify_source!(%Export{} = export, graph, _inputs) do
    unless export.graph_id == graph.id and Enum.member?(graph.exports, export) do
      raise ArgumentError,
            "graph export #{inspect(export.name || export.ref)} is not exported by the command graph"
    end

    case Map.fetch!(graph.nodes, export.ref.node_id) do
      %{kind: :input, input_ref: reference} -> single_input!(reference, export.media)
      %{kind: :filter} -> {{:filter, export.ref}, export.media, true}
    end
  end

  defp classify_source!(other, _graph, _inputs) do
    raise ArgumentError, "invalid output source: #{inspect(other)}"
  end

  defp single_input!(reference, media) do
    unless InputRef.single?(reference.selector) do
      raise ArgumentError,
            "graph input matchers are not single output streams; use an indexed reference or an input selection"
    end

    {{:input, reference, false}, media, true}
  end

  defp output_streams!(mappings) do
    {streams, _counts} =
      mappings
      |> Enum.with_index()
      |> Enum.reduce({%{}, %{}}, fn {mapping, index}, {streams, counts} ->
        unless mapping.single do
          raise ArgumentError,
                "output option callbacks require every mapping to select one stream; use indexed inputs or filtered exports"
        end

        if mapping.media == :unknown do
          raise ArgumentError,
                "output option callbacks require known media for every mapping; absolute input indexes cannot supply media-relative specifiers; use indexed media selectors or Filter.filter/4 with explicit media"
        end

        media_index = Map.get(counts, mapping.media, 0)
        specifier = "#{InputRef.media_prefix(mapping.media)}:#{media_index}"

        streams =
          if mapping.name == nil do
            streams
          else
            Map.put(streams, mapping.name, %{index: index, specifier: specifier})
          end

        {streams, Map.put(counts, mapping.media, media_index + 1)}
      end)

    streams
  end

  defp validate_export_mappings!(nil, _outputs), do: :ok

  defp validate_export_mappings!(graph, outputs) do
    counts =
      Enum.reduce(outputs, %{}, fn output, counts ->
        Enum.reduce(output.sources, counts, fn
          {:filter, ref}, counts -> Map.update(counts, ref, 1, &(&1 + 1))
          {:input, _reference, _optional}, counts -> counts
        end)
      end)

    Enum.each(graph.exports, fn export ->
      if Map.fetch!(graph.nodes, export.ref.node_id).kind == :filter do
        case Map.get(counts, export.ref, 0) do
          1 ->
            :ok

          0 ->
            raise ArgumentError,
                  "graph output #{inspect(export.name || export.ref)} must be mapped exactly once"

          count ->
            raise ArgumentError,
                  "graph output #{inspect(export.name || export.ref)} is mapped #{count} times; complex filter outputs must be mapped exactly once"
        end
      end
    end)
  end
end
