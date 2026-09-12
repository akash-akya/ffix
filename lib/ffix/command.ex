defmodule FFix.Command do
  @moduledoc """
  Canonical representation of a full ffmpeg command.

  A command stores global options, ordered inputs, an optional filtergraph, and
  ordered outputs. It is still just data until `FFix.to_argv/1`, `FFix.run/1`, or
  another boundary function serializes it.

  Prefer `FFix.command/2` for the output-first API. Use this module directly
  when you want to construct or transform `%FFix.Command{}` values in smaller
  steps. Supply inputs explicitly and map direct input selections or canonical
  `graph.exports` handles with their graph. This layer does not collect graph
  reference contexts or infer dependencies. Captured input snapshots must still
  match the supplied declarations.

  ## Examples

      input = FFix.Command.Input.new("input.mp4", ss: "00:00:03", stream_loop: -1)
      video = FFix.video(input, :all)

      command =
        FFix.Command.new(
          global: [y: :flag],
          inputs: [input],
          outputs: [FFix.Command.Output.new(video, "out.mp4", vcodec: :copy)]
        )

      FFix.to_argv(command)
      #=> [
      #=>   "ffmpeg",
      #=>   "-y",
      #=>   "-ss",
      #=>   "00:00:03",
      #=>   "-stream_loop",
      #=>   "-1",
      #=>   "-i",
      #=>   "input.mp4",
      #=>   "-map",
      #=>   "0:v",
      #=>   "-vcodec",
      #=>   "copy",
      #=>   "out.mp4"
      #=> ]

  Use `FFix.Decoder`, `FFix.Encoder`, `FFix.Muxer`, and `FFix.Command.Mapping`
  for structured configuration. Decoder settings belong to input declarations;
  encoding belongs to ordered output mappings; muxer settings belong to outputs.
  This path assigns stream indexes without discovery or media probing.

  Raw option keys remain ffmpeg CLI option names. For raw options with stream
  specifiers, use an atom or string key that already contains the specifier,
  for example `:"c:v"` or `"metadata:s:a:0"`. Do not use raw options to override
  structured configuration or alter the mapping order it relies on.
  """
  @moduledoc groups: [
               "Construction",
               "Inputs",
               "Filtergraph",
               "Outputs",
               "Validation",
               "Serialization"
             ]

  alias __MODULE__.Input
  alias __MODULE__.Mapping
  alias __MODULE__.Output
  alias __MODULE__.Encoding
  alias FFix.Decoder
  alias FFix.Demuxer
  alias FFix.Encoder
  alias FFix.Muxer
  alias FFix.Options
  alias FFix.Graph
  alias FFix.Graph.Export
  alias FFix.Graph.InputRef
  alias FFix.Graph.StreamRef
  alias FFix.Selection

  @type option :: {atom() | String.t(), term()}
  @type av_value :: String.t() | atom() | number()
  @type av_option :: {atom() | String.t(), av_value()}
  @type stream_info :: %{index: non_neg_integer(), specifier: String.t()}
  @type streams :: %{atom() => stream_info()}
  @type option_callback :: (streams() -> term())
  @type output_av_option :: {atom() | String.t(), av_value() | option_callback()}
  @type source :: Export.t() | StreamRef.t() | Selection.t()
  @type mapping :: Mapping.t() | source()
  @type binding :: mapping() | {atom(), mapping()}

  @codec_selection_options ~w(c codec vcodec acodec scodec dcodec)
  @graph_options ~w(filter_complex filter_complex_script lavfi)
  @mapping_options ~w(i map map_channel attach vn an sn dn) ++ @graph_options

  @type t :: %__MODULE__{
          global_options: [option()],
          inputs: [Input.t()],
          graph: Graph.t() | nil,
          outputs: [Output.t()]
        }

  defstruct global_options: [], inputs: [], graph: nil, outputs: []

  @doc group: "Construction"
  @doc """
  Returns an empty command.

  This is useful when building a command step by step with `global/2`,
  `add_input/2`, `graph/2`, and `add_output/2`.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc group: "Construction"
  @doc """
  Builds a command from already-normalized command data.

  This lower-level constructor expects ordered input and output structs. For the
  output-first API, use `FFix.command/2`. Filtered mappings here require canonical
  exports from the explicit `:graph`; no dependency inference occurs.

      src = FFix.Command.Input.new("input.mp4")
      video = FFix.video(src, 0)

      FFix.Command.new(
        inputs: [src],
        outputs: [FFix.Command.Output.new(video, "out.mp4", "c:v": :copy)]
      )
  """
  @spec new(keyword()) :: t()
  def new(options) when is_list(options) do
    validate_command_keys!(options)

    graph = normalize_graph!(Keyword.get(options, :graph))
    outputs = normalize_outputs!(Keyword.get(options, :outputs, []))

    %__MODULE__{
      global_options: normalize_option_list!(Keyword.get(options, :global, []), :global),
      inputs: normalize_inputs!(Keyword.get(options, :inputs, [])),
      graph: graph,
      outputs: outputs
    }
  end

  @doc group: "Construction"
  @doc """
  Appends global ffmpeg options to a command.

  Global options are rendered before inputs:

      FFix.Command.new()
      |> FFix.Command.global(y: :flag, loglevel: :error)
  """
  @spec global(t(), keyword()) :: t()
  def global(%__MODULE__{global_options: global_options} = command, options)
      when is_list(options) do
    %{command | global_options: global_options ++ options}
  end

  @doc group: "Inputs"
  @doc "Appends an existing input declaration to a low-level command."
  @spec add_input(t(), Input.t()) :: t()
  def add_input(%__MODULE__{} = command, %Input{} = input) do
    %{command | inputs: command.inputs ++ [input]}
  end

  @doc group: "Filtergraph"
  @doc """
  Sets the filtergraph for a command.
  """
  @spec graph(t(), Graph.t()) :: t()
  def graph(%__MODULE__{} = command, %Graph{} = graph) do
    %{command | graph: graph}
  end

  @doc group: "Outputs"
  @doc "Appends an existing output declaration to a low-level command."
  @spec add_output(t(), Output.t()) :: t()
  def add_output(%__MODULE__{} = command, %Output{} = output) do
    %{command | outputs: command.outputs ++ [output]}
  end

  @doc group: "Validation"
  @doc """
  Validates command structure.

  This checks declared inputs, graph references, output sources, and filtered
  graph export mappings. It does not run ffmpeg, inspect media files, or evaluate
  deferred output option callbacks. Their returned values are checked during
  serialization.
  """
  @spec validate!(t()) :: t()
  def validate!(%__MODULE__{} = command) do
    validate_cli_options!(command.global_options)
    validate_option_callbacks!(command.global_options, false)

    Enum.each(command.inputs, fn input ->
      case input do
        %Input{} ->
          validate_input!(input)

        other ->
          raise ArgumentError, "invalid command input: #{inspect(other)}"
      end
    end)

    input_index_map = input_index_map!(command.inputs)

    if command.outputs == [] do
      raise ArgumentError, "command requires at least one output"
    end

    input_count = length(command.inputs)

    graph =
      case command.graph do
        nil ->
          nil

        %Graph{} = graph ->
          graph |> resolve_graph_inputs!(input_count, input_index_map) |> FFix.validate!()

        other ->
          raise ArgumentError, "invalid command graph: #{inspect(other)}"
      end

    Enum.each(command.outputs, fn output ->
      case output do
        %Output{} -> validate_output!(output, graph, input_count, input_index_map)
        other -> raise ArgumentError, "invalid command output: #{inspect(other)}"
      end
    end)

    configured_mappings? =
      Enum.any?(command.outputs, fn output ->
        Enum.any?(output.mappings, &(&1.encoding != nil)) or output_callbacks?(output)
      end)

    if configured_mappings? do
      validate_raw_options!(command.global_options, ["i" | @graph_options], "configured mappings")

      Enum.each(command.inputs, fn input ->
        validate_raw_options!(input.options, ["i" | @graph_options], "configured mappings")
      end)
    end

    validate_input_snapshots!(command.inputs, graph, command.outputs, input_index_map)
    validate_graph_export_mappings!(command.outputs, graph)
    command
  end

  @doc group: "Serialization"
  @doc """
  Serializes a command to ffmpeg argv.

  The returned list is the canonical boundary for executing a command. Prefer it
  over shell strings when passing argv to another process.
  """
  @spec to_argv(t()) :: [String.t()]
  def to_argv(%__MODULE__{} = command) do
    command = validate!(command)
    input_index_map = input_index_map!(command.inputs)
    input_count = length(command.inputs)

    graph =
      if command.graph, do: resolve_graph_inputs!(command.graph, input_count, input_index_map)

    render = if graph, do: FFix.Graph.Render.render(graph)

    ["ffmpeg"] ++
      encode_options(command.global_options) ++
      Enum.flat_map(command.inputs, &input_to_argv/1) ++
      graph_to_argv(render) ++
      Enum.flat_map(
        command.outputs,
        &output_to_argv(&1, graph, render, input_count, input_index_map)
      )
  end

  @doc group: "Serialization"
  @doc """
  Serializes a command as a shell-escaped string for logs and debugging.
  """
  @spec to_shell_string(t()) :: String.t()
  def to_shell_string(%__MODULE__{} = command) do
    command
    |> to_argv()
    |> Enum.map_join(" ", &shell_escape/1)
  end

  defp validate_command_keys!(options) do
    unless Keyword.keyword?(options),
      do: raise(ArgumentError, "command options must be a keyword list")

    keys = Keyword.keys(options)

    if length(keys) != length(Enum.uniq(keys)),
      do: raise(ArgumentError, "duplicate command option")

    unknown = keys -- [:global, :inputs, :graph, :outputs]

    if unknown != [] do
      raise ArgumentError, "unknown command keys: #{inspect(unknown)}"
    end
  end

  defp normalize_option_list!(options, _key) when is_list(options), do: options

  defp normalize_option_list!(_options, key) do
    raise ArgumentError, "command #{key} must be a keyword list"
  end

  defp normalize_inputs!(inputs) when is_list(inputs) do
    Enum.each(inputs, fn
      %Input{} -> :ok
      other -> raise ArgumentError, "invalid command input: #{inspect(other)}"
    end)

    inputs
  end

  defp normalize_inputs!(_inputs) do
    raise ArgumentError, "command inputs must be a list"
  end

  defp normalize_graph!(nil), do: nil
  defp normalize_graph!(%Graph{} = graph), do: graph

  defp normalize_graph!(graph) do
    raise ArgumentError, "invalid command graph: #{inspect(graph)}"
  end

  defp normalize_outputs!(outputs) when is_list(outputs) do
    Enum.each(outputs, fn
      %Output{} -> :ok
      other -> raise ArgumentError, "invalid command output: #{inspect(other)}"
    end)

    outputs
  end

  defp normalize_outputs!(_outputs) do
    raise ArgumentError, "command outputs must be a list"
  end

  @doc false
  def validate_input!(%Input{} = input) do
    validate_endpoint!(input.source, :input)
    validate_cli_options!(input.options)

    unless is_nil(input.id) or is_reference(input.id) do
      raise ArgumentError, "input identity must be a reference or nil"
    end

    validate_option_callbacks!(input.options, false)
    validate_demuxer!(input)
    validate_decoders!(input)
    input
  end

  defp validate_demuxer!(%Input{demuxer: demuxer, options: options}) do
    case demuxer do
      nil ->
        :ok

      %Demuxer{} ->
        validate_component!(demuxer)
        reserved = ["f" | component_option_names([demuxer])]
        validate_raw_options!(options, reserved, "a structured demuxer")

      other ->
        raise ArgumentError, "invalid demuxer configuration: #{inspect(other)}"
    end
  end

  defp validate_decoders!(%Input{decoders: decoders, options: options}) do
    unless is_map(decoders) and not is_struct(decoders) do
      raise ArgumentError, "input decoders must be a map of indexed selectors to Decoder values"
    end

    Enum.each(decoders, fn {selector, decoder} ->
      validate_decoder!(selector, decoder)
    end)

    namespaces =
      decoders
      |> Map.keys()
      |> Enum.map(fn
        {:index, _index} -> :absolute
        {_media, _index} -> :media_relative
      end)
      |> Enum.uniq()

    if length(namespaces) > 1 do
      raise ArgumentError,
            "cannot mix absolute and media-relative decoder selectors on one input"
    end

    if map_size(decoders) > 0 do
      configured_options = component_option_names(Map.values(decoders))
      reserved = @codec_selection_options ++ configured_options
      validate_raw_options!(options, reserved, "structured decoding")
    end
  end

  defp validate_input_snapshots!(inputs, graph, outputs, input_index_map) do
    graph_refs =
      if graph do
        graph |> Graph.nodes() |> Enum.filter(&(&1.kind == :input)) |> Enum.map(& &1.input_ref)
      else
        []
      end

    direct_refs =
      Enum.flat_map(outputs, fn output ->
        Enum.flat_map(output.mappings, fn
          %Mapping{source: %Selection{input_ref: input_ref}} -> [input_ref]
          %Mapping{source: %StreamRef{} = stream} -> [StreamRef.node!(stream).input_ref]
          _mapping -> []
        end)
      end)

    Enum.each(graph_refs ++ direct_refs, fn
      %InputRef{declaration: nil} ->
        :ok

      %InputRef{declaration: declaration} = input_ref ->
        resolved = resolve_input_ref!(input_ref, length(inputs), input_index_map)

        if Enum.at(inputs, resolved.input) != declaration do
          raise ArgumentError, "conflicting input snapshots for #{inspect(input_ref.input)}"
        end
    end)
  end

  defp validate_output!(output, graph, input_count, input_index_map) do
    validate_endpoint!(output.target, :output)
    validate_cli_options!(output.options)

    unless is_list(output.mappings) do
      raise ArgumentError, "output mappings must be a list of Mapping values"
    end

    if output.mappings == [] do
      raise ArgumentError, "output requires at least one source"
    end

    validate_mapping_names!(output.mappings)
    validate_option_callbacks!(output.options, true)

    Enum.each(output.mappings, fn mapping ->
      case mapping do
        %Mapping{source: source, encoding: encoding} ->
          validate_source!(source, graph, input_count, input_index_map)
          validate_encoding!(encoding, source, graph)

        other ->
          raise ArgumentError, "invalid output mapping: #{inspect(other)}"
      end
    end)

    encodings = Enum.map(output.mappings, & &1.encoding)

    if Enum.any?(encodings, &(&1 != nil)) do
      encoding_plan!(output.mappings, graph)

      configured_options = component_option_names(encodings)
      reserved = @codec_selection_options ++ @mapping_options ++ configured_options
      validate_raw_options!(output.options, reserved, "structured encoding")
    end

    case output.muxer do
      nil ->
        :ok

      %Muxer{} = muxer ->
        validate_component!(muxer)
        reserved = ["f" | component_option_names([muxer])]
        validate_raw_options!(output.options, reserved, "a structured muxer")

      other ->
        raise ArgumentError, "invalid muxer configuration: #{inspect(other)}"
    end

    if output_callbacks?(output) do
      validate_raw_options!(output.options, @mapping_options, "output option callbacks")
      output_streams!(output, graph)
    end
  end

  defp validate_mapping_names!(mappings) do
    Enum.reduce(mappings, MapSet.new(), fn mapping, names ->
      case mapping do
        %Mapping{name: nil} ->
          names

        %Mapping{name: name} when is_atom(name) and name not in [true, false] ->
          if MapSet.member?(names, name) do
            raise ArgumentError, "duplicate output mapping name: #{inspect(name)}"
          end

          MapSet.put(names, name)

        %Mapping{name: name} ->
          raise ArgumentError, "output mapping name must be an atom or nil, got: #{inspect(name)}"

        other ->
          raise ArgumentError, "invalid output mapping: #{inspect(other)}"
      end
    end)
  end

  defp validate_option_callbacks!(options, allowed?) do
    {_special, options} = Options.split!(options, [])

    Enum.each(options, fn {name, value} ->
      if is_function(value) do
        unless allowed? do
          raise ArgumentError, "option callbacks are only supported on outputs: #{inspect(name)}"
        end

        unless is_function(value, 1) do
          raise ArgumentError, "option callback #{inspect(name)} must accept one streams argument"
        end
      end
    end)
  end

  defp output_callbacks?(output) do
    components = [output.muxer | Enum.map(output.mappings, & &1.encoding)]

    component_options =
      Enum.flat_map(components, fn component ->
        case component do
          %{options: options} -> options
          _unconfigured -> []
        end
      end)

    Enum.any?(output.options ++ component_options, fn {_name, value} -> is_function(value) end)
  end

  defp output_streams!(output, graph) do
    {streams, _counts} =
      output.mappings
      |> Enum.with_index()
      |> Enum.reduce({%{}, %{}}, fn {mapping, index}, {streams, counts} ->
        unless single_source?(mapping.source, graph) do
          raise ArgumentError,
                "output option callbacks require every mapping to select one stream; use indexed inputs or filtered exports"
        end

        media = source_media(mapping.source, graph)

        if media == :unknown do
          raise ArgumentError,
                "output option callbacks require known media for every mapping; absolute input indexes cannot supply media-relative specifiers; use indexed media selectors or Filter.filter/4 with explicit media"
        end

        prefix = InputRef.media_prefix(media)
        media_index = Map.get(counts, media, 0)
        info = %{index: index, specifier: "#{prefix}:#{media_index}"}
        counts = Map.put(counts, media, media_index + 1)

        streams =
          case mapping.name do
            nil -> streams
            name -> Map.put(streams, name, info)
          end

        {streams, counts}
      end)

    streams
  end

  defp source_media(%Selection{} = selection, _graph), do: Selection.media(selection)
  defp source_media(source, _graph), do: source.media

  defp encoding_plan!(mappings, graph) do
    mappings
    |> Enum.map(fn mapping ->
      %{
        single: single_source?(mapping.source, graph),
        media: source_media(mapping.source, graph),
        encoding: mapping.encoding
      }
    end)
    |> Encoding.plan!()
  end

  defp validate_encoding!(encoding, source, graph) do
    case encoding do
      nil ->
        :ok

      :copy ->
        if not is_struct(source, Selection) and source_node(source, graph).kind == :filter do
          raise ArgumentError, "cannot copy a filtered source; use an encoder"
        end

      %Encoder{} = encoder ->
        validate_component!(encoder)

      other ->
        raise ArgumentError, "invalid encoding configuration: #{inspect(other)}"
    end
  end

  defp single_source?(%Selection{}, _graph), do: false

  defp single_source?(source, graph) do
    case source_node(source, graph) do
      %{kind: :filter} -> true
      %{kind: :input, input_ref: input_ref} -> InputRef.single?(input_ref.selector)
    end
  end

  defp source_node(source, graph) do
    case source do
      %StreamRef{} = stream ->
        StreamRef.node!(stream)

      %Export{ref: ref} ->
        Map.fetch!(graph.nodes, ref.node_id)
    end
  end

  @doc false
  def validate_decoder!(selector, decoder) do
    unless InputRef.single?(selector) and
             elem(selector, 0) in [:video, :audio, :subtitle, :data, :attachment, :index] do
      raise ArgumentError,
            "decoder selector must be {media, nonnegative_index} or {:index, nonnegative_index}, got: #{inspect(selector)}"
    end

    case decoder do
      %Decoder{} -> validate_component!(decoder)
      other -> raise ArgumentError, "invalid decoder configuration: #{inspect(other)}"
    end
  end

  @doc false
  def validate_component!(component) do
    unless is_nil(component.name) or
             (is_binary(component.name) and component.name != "" and
                not String.contains?(component.name, <<0>>)) do
      raise ArgumentError, "component name must be a non-empty string or nil"
    end

    if match?(%Encoder{name: "copy"}, component) do
      raise ArgumentError, "copy is a mapping mode; use encoding: :copy"
    end

    unless is_list(component.options) do
      raise ArgumentError, "component options must be an ordered list of name/value pairs"
    end

    Enum.each(component.options, fn option ->
      case option do
        {key, value} when is_atom(key) or is_binary(key) ->
          validate_av_option!(encode_option_key(key), value)

        other ->
          raise ArgumentError, "invalid component option: #{inspect(other)}"
      end
    end)

    names = Enum.map(component.options, fn {key, _value} -> encode_option_key(key) end)

    if length(names) != length(Enum.uniq(names)),
      do: raise(ArgumentError, "duplicate component option; specify each option once")

    callbacks? = is_struct(component, Encoder) or is_struct(component, Muxer)
    validate_option_callbacks!(component.options, callbacks?)
    component
  end

  defp validate_av_option!(name, value) do
    invalid_name? =
      name == "" or String.starts_with?(name, "-") or
        String.contains?(name, [":", " ", "\t", "\n", "\r", "\0"])

    if invalid_name? do
      raise ArgumentError,
            "component option names must be unscoped names without leading dashes, got: #{inspect(name)}"
    end

    if name in (@codec_selection_options ++ @mapping_options ++ ["f"]) do
      raise ArgumentError, "#{inspect(name)} is a CLI control, not a component AVOption"
    end

    if is_binary(value) and String.contains?(value, <<0>>),
      do: raise(ArgumentError, "component option values cannot contain NUL")

    scalar? = is_binary(value) or is_number(value) or (is_atom(value) and not is_nil(value))

    unless scalar? or is_function(value, 1) do
      raise ArgumentError,
            "component option values must be strings, atoms, numbers, or booleans; use strings for compound values, got: #{inspect(value)}"
    end
  end

  defp component_option_names(components) do
    Enum.flat_map(components, fn component ->
      case component do
        nil -> []
        :copy -> []
        %{options: options} -> Enum.map(options, fn {key, _value} -> encode_option_key(key) end)
      end
    end)
  end

  defp validate_raw_options!(options, reserved, owner) do
    reserved = Enum.map(reserved, &canonical_option_name/1)

    Enum.each(options, fn {key, _value} ->
      name = encode_option_key(key)
      [base_name | _specifier] = String.split(name, ":", parts: 2)

      canonical_name = canonical_option_name(base_name)

      if base_name in reserved or canonical_name in reserved do
        raise ArgumentError, "raw option #{inspect(name)} cannot be combined with #{owner}"
      end
    end)
  end

  defp validate_source!(%Export{} = export, nil, _input_count, _input_index_map) do
    raise ArgumentError, "graph export #{inspect(export.name || export.ref)} requires a graph"
  end

  defp validate_source!(%Export{} = export, %Graph{} = graph, _input_count, _input_index_map) do
    unless export.graph_id == graph.id and Enum.member?(graph.exports, export) do
      raise ArgumentError,
            "graph export #{inspect(export.name || export.ref)} is not exported by the command graph"
    end

    case Map.fetch!(graph.nodes, export.ref.node_id) do
      %{kind: :input, input_ref: input_ref} -> validate_mapped_input!(input_ref)
      _filter -> :ok
    end
  end

  defp validate_source!(%Selection{} = selection, _graph, input_count, input_index_map) do
    Selection.validate!(selection)
    resolve_input_ref!(selection.input_ref, input_count, input_index_map)
    :ok
  end

  defp validate_source!(%StreamRef{} = stream, _graph, input_count, input_index_map) do
    resolve_stream_source!(stream, input_count, input_index_map)
    :ok
  end

  defp validate_source!(source, _graph, _input_count, _input_index_map) do
    raise ArgumentError, "invalid output source: #{inspect(source)}"
  end

  defp validate_graph_export_mappings!(_outputs, nil), do: :ok

  defp validate_graph_export_mappings!(outputs, %Graph{} = graph) do
    export_counts =
      Enum.reduce(outputs, %{}, fn %Output{mappings: mappings}, counts ->
        Enum.reduce(mappings, counts, fn mapping, counts ->
          case mapped_filter_export(mapping.source, graph) do
            nil -> counts
            %Export{ref: ref} -> Map.update(counts, ref_key(ref), 1, &(&1 + 1))
          end
        end)
      end)

    Enum.each(graph.exports, fn %Export{} = export ->
      if filter_export?(graph, export) do
        count = Map.get(export_counts, ref_key(export.ref), 0)

        case count do
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

  defp mapped_filter_export(%Export{} = export, %Graph{} = graph) do
    if filter_export?(graph, export), do: export, else: nil
  end

  defp mapped_filter_export(%StreamRef{}, %Graph{}), do: nil
  defp mapped_filter_export(%Selection{}, %Graph{}), do: nil

  defp filter_export?(%Graph{} = graph, %Export{ref: ref}) do
    case Map.fetch!(graph.nodes, ref.node_id) do
      %{kind: :filter} -> true
      _node -> false
    end
  end

  defp ref_key(%FFix.Graph.Ref{node_id: node_id, output: output}), do: {node_id, output}

  defp input_to_argv(%Input{
         source: source,
         options: options,
         demuxer: demuxer,
         decoders: decoders
       }) do
    decoder_options =
      decoders
      |> Enum.sort_by(fn {selector, _decoder} -> selector end)
      |> Enum.flat_map(fn {selector, decoder} ->
        component_to_argv(decoder, encode_stream_selector(selector))
      end)

    encode_options(options) ++
      component_to_argv(demuxer, nil) ++ decoder_options ++ ["-i", encode_input_source(source)]
  end

  defp graph_to_argv(nil), do: []
  defp graph_to_argv(%{graph: ""}), do: []
  defp graph_to_argv(%{graph: graph}), do: ["-filter_complex", graph]

  defp output_to_argv(
         %Output{} = output,
         graph,
         render,
         input_count,
         input_index_map
       ) do
    output = resolve_output_options!(output, graph)
    %Output{target: target, mappings: mappings, muxer: muxer, options: options} = output

    maps =
      Enum.flat_map(mappings, fn mapping ->
        source = map_source(mapping.source, graph, render, input_count, input_index_map)
        ["-map", source]
      end)

    encoding_options =
      mappings
      |> encoding_plan!(graph)
      |> Enum.flat_map(fn
        {:copy, nil} -> ["-c", "copy"]
        {:copy, selector} -> ["-c:#{selector}", "copy"]
        {%Encoder{} = encoder, selector} -> component_to_argv(encoder, selector)
      end)

    maps ++
      encoding_options ++
      component_to_argv(muxer, nil) ++
      encode_options(options) ++
      [encode_output_target(target)]
  end

  defp resolve_output_options!(output, graph) do
    if output_callbacks?(output) do
      streams = output_streams!(output, graph)

      mappings =
        Enum.map(output.mappings, fn mapping ->
          %{mapping | encoding: resolve_component_options!(mapping.encoding, streams)}
        end)

      options = Options.resolve!(output.options, streams)
      validate_cli_options!(options)

      %{
        output
        | mappings: mappings,
          muxer: resolve_component_options!(output.muxer, streams),
          options: options
      }
    else
      output
    end
  end

  defp resolve_component_options!(component, streams) do
    case component do
      %{options: options} ->
        resolved = %{component | options: Options.resolve!(options, streams)}
        validate_component!(resolved)

      unconfigured ->
        unconfigured
    end
  end

  defp map_source(%Selection{} = selection, _graph, _render, input_count, input_index_map) do
    reference = resolve_input_ref!(selection.input_ref, input_count, input_index_map)
    source = encode_input_ref(reference)
    if selection.optional and not String.ends_with?(source, "?"), do: source <> "?", else: source
  end

  defp map_source(%StreamRef{} = stream, _graph, _render, input_count, input_index_map) do
    stream
    |> resolve_stream_source!(input_count, input_index_map)
    |> encode_input_ref()
  end

  defp map_source(%Export{} = export, %Graph{} = graph, render, _input_count, _input_index_map) do
    node = Map.fetch!(graph.nodes, export.ref.node_id)

    case node.kind do
      :input ->
        encode_input_ref(node.input_ref)

      :filter ->
        export_label!(export, render)
    end
  end

  defp export_label!(%Export{} = export, %{exports: exports}) do
    exports
    |> Enum.find(fn rendered_export ->
      rendered_export.name == export.name and rendered_export.ref == export.ref
    end)
    |> case do
      %{label: label} -> "[#{label}]"
      nil -> raise ArgumentError, "unable to resolve export #{inspect(export.name || export.ref)}"
    end
  end

  defp input_index_map!(inputs) do
    inputs
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {%Input{id: id}, index}, index_map ->
      put_input_key!(index_map, id, index, fn -> "duplicate command input declaration" end)
    end)
  end

  defp put_input_key!(index_map, nil, _index, _message_fun), do: index_map

  defp put_input_key!(index_map, key, index, message_fun) do
    if Map.has_key?(index_map, key) do
      raise ArgumentError, message_fun.()
    else
      Map.put(index_map, key, index)
    end
  end

  defp resolve_graph_inputs!(%Graph{} = graph, input_count, input_index_map) do
    nodes =
      Map.new(graph.nodes, fn
        {node_id, %{kind: :input, input_ref: %InputRef{} = input_ref} = node} ->
          {node_id,
           %{node | input_ref: resolve_input_ref!(input_ref, input_count, input_index_map)}}

        entry ->
          entry
      end)

    %{graph | nodes: nodes}
  end

  defp resolve_input_ref!(%InputRef{input: input} = input_ref, input_count, _input_index_map)
       when is_integer(input) do
    if input < input_count do
      input_ref
    else
      raise ArgumentError, "input #{input} is not declared in the command"
    end
  end

  defp resolve_input_ref!(%InputRef{input: input} = input_ref, _input_count, input_index_map)
       when is_binary(input) or is_reference(input) do
    case input_index_map[input] do
      nil -> raise ArgumentError, "input #{inspect(input)} is not declared in the command"
      index -> %{input_ref | input: index}
    end
  end

  defp resolve_input_ref!(%InputRef{input: input}, _input_count, _input_index_map) do
    raise ArgumentError, "invalid input ref #{inspect(input)}"
  end

  defp resolve_stream_source!(%StreamRef{} = stream, input_count, input_index_map) do
    node = StreamRef.node!(stream)
    FFix.Graph.Builder.validate_graph!(stream.graph, allow_unused: true)

    unless node.kind == :input and map_size(stream.graph.nodes) == 1 and
             stream.graph.settings == [] do
      raise ArgumentError,
            "graph references require FFix.command/2 or canonical graph.exports handles with an explicit graph"
    end

    resolved = resolve_input_ref!(node.input_ref, input_count, input_index_map)
    validate_mapped_input!(resolved)
    resolved
  end

  defp validate_mapped_input!(input_ref) do
    unless InputRef.single?(input_ref.selector),
      do:
        raise(
          ArgumentError,
          "graph input matchers are not single output streams; use an indexed reference or an input selection"
        )
  end

  defp component_to_argv(component, selector) do
    case component do
      nil ->
        []

      %{name: name, options: options} ->
        selection_option =
          case component do
            %Muxer{} -> "f"
            %Demuxer{} -> "f"
            %Decoder{} -> "c"
            %Encoder{} -> "c"
          end

        suffix =
          case selector do
            nil -> ""
            selector -> ":#{selector}"
          end

        selection =
          case name do
            nil -> []
            name -> ["-#{selection_option}#{suffix}", name]
          end

        av_options =
          Enum.flat_map(options, fn {key, value} ->
            ["-#{encode_option_key(key)}#{suffix}", encode_option_value(value)]
          end)

        selection ++ av_options
    end
  end

  defp encode_options(options) do
    Enum.flat_map(options, &encode_option/1)
  end

  defp encode_option({key, :flag}), do: ["-#{encode_option_key(key)}"]

  defp encode_option({key, value}) do
    ["-#{encode_option_key(key)}", encode_cli_value(value)]
  end

  defp encode_cli_value(true), do: "1"
  defp encode_cli_value(false), do: "0"

  defp encode_cli_value(values) when is_list(values),
    do: Enum.map_join(values, "+", &encode_cli_value/1)

  defp encode_cli_value(value), do: encode_option_value(value)

  defp encode_option_key(key) when is_atom(key), do: Atom.to_string(key)
  defp encode_option_key(key) when is_binary(key), do: key

  # Command option values are intentionally simple for now.
  # Use string keys or values directly when ffmpeg expects more specific syntax.
  defp encode_option_value(value) when is_boolean(value), do: to_string(value)
  defp encode_option_value(value) when is_integer(value), do: Integer.to_string(value)

  defp encode_option_value(value) when is_float(value), do: encode_float_option_value(value)

  defp encode_option_value(value) when is_atom(value), do: Atom.to_string(value)

  defp encode_option_value(value) when is_list(value),
    do: Enum.map_join(value, "+", &encode_option_value/1)

  defp encode_option_value(value) when is_binary(value), do: value

  defp encode_option_value(value) do
    raise ArgumentError, "invalid CLI option value: #{inspect(value)}"
  end

  defp canonical_option_name(name) when name in ["ab", "vb"], do: "b"
  defp canonical_option_name(name), do: name

  @doc false
  def validate_endpoint!(endpoint, direction) do
    valid? =
      case endpoint do
        value when is_binary(value) -> value != "" and not String.contains?(value, <<0>>)
        {:url, value} when is_binary(value) -> value != "" and not String.contains?(value, <<0>>)
        {:pipe, descriptor} when is_integer(descriptor) and descriptor >= 0 -> true
        :stdin -> direction == :input
        :stdout -> direction == :output
        _ -> false
      end

    unless valid?,
      do: raise(ArgumentError, "invalid #{direction} source/target: #{inspect(endpoint)}")

    endpoint
  end

  @doc false
  def validate_cli_options!(options) do
    {_special, options} = Options.split!(options, [])

    Enum.each(options, fn {key, value} ->
      name = encode_option_key(key)

      if name == "" or String.starts_with?(name, "-") or
           String.contains?(name, [" ", "\t", "\n", "\r", <<0>>]),
         do: raise(ArgumentError, "invalid CLI option name: #{inspect(name)}")

      validate_cli_value!(value)
    end)
  end

  defp validate_cli_value!(value) when is_function(value, 1), do: :ok

  defp validate_cli_value!(value) when is_binary(value) do
    if String.contains?(value, <<0>>),
      do: raise(ArgumentError, "CLI option values cannot contain NUL")

    :ok
  end

  defp validate_cli_value!(nil),
    do: raise(ArgumentError, "nil is not a CLI option value; use :flag for a valueless switch")

  defp validate_cli_value!(value) when is_atom(value) or is_number(value), do: :ok

  defp validate_cli_value!(values) when is_list(values) do
    Enum.each(values, fn value ->
      if is_function(value), do: raise(ArgumentError, "callbacks must be complete option values")
      validate_cli_value!(value)
    end)
  end

  defp validate_cli_value!(value) when is_function(value), do: :ok

  defp validate_cli_value!(value),
    do: raise(ArgumentError, "invalid CLI option value: #{inspect(value)}")

  defp encode_input_source(:stdin), do: "pipe:0"
  defp encode_input_source({:pipe, fd}) when is_integer(fd) and fd >= 0, do: "pipe:#{fd}"
  defp encode_input_source({:url, url}) when is_binary(url), do: url
  defp encode_input_source(source) when is_binary(source), do: source

  defp encode_output_target(:stdout), do: "pipe:1"
  defp encode_output_target({:pipe, fd}) when is_integer(fd) and fd >= 0, do: "pipe:#{fd}"
  defp encode_output_target({:url, url}) when is_binary(url), do: url
  defp encode_output_target(target) when is_binary(target), do: target

  defp encode_input_ref(%InputRef{input: input, selector: selector}) do
    case InputRef.selector_string(selector) do
      "" -> to_string(input)
      suffix -> "#{input}:#{suffix}"
    end
  end

  defp encode_stream_selector(selector), do: InputRef.selector_string(selector)

  defp encode_float_option_value(value) do
    FFix.Value.float_to_string(value)
  end

  defp shell_escape(""), do: "''"

  defp shell_escape(argument) do
    if String.match?(argument, ~r|^[A-Za-z0-9_@%+=:,./-]+$|) do
      argument
    else
      "'" <> String.replace(argument, "'", ~S('"'"')) <> "'"
    end
  end
end
