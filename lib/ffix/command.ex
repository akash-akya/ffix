defmodule FFix.Command do
  @moduledoc """
  Canonical representation of a full ffmpeg command.

  A command stores global options, ordered inputs, an optional filtergraph, and
  ordered outputs. It is still just data until `FFix.to_argv/1`, `FFix.run/1`, or
  another boundary function serializes it.

  Prefer `FFix.command/3` for the function-based API. Use this module directly
  when you want to construct or transform `%FFix.Command{}` values in smaller
  steps.

  ## Examples

      input = FFix.Command.input("input.mp4", ss: "00:00:03", stream_loop: -1)
      video = input[:video]

      command =
        FFix.Command.new(
          global: [y: true],
          inputs: [input],
          outputs: [FFix.Command.output(video, "out.mp4", vcodec: :copy)]
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
  alias FFix.Decoder
  alias FFix.Demuxer
  alias FFix.Encoder
  alias FFix.Muxer
  alias FFix.Options
  alias FFix.Graph
  alias FFix.Graph.Export
  alias FFix.Graph.InputRef
  alias FFix.Graph.StreamRef

  @type option :: {atom() | String.t(), term()}
  @type av_value :: String.t() | atom() | number()
  @type av_option :: {atom() | String.t(), av_value()}
  @type stream_info :: %{index: non_neg_integer(), specifier: String.t()}
  @type streams :: %{atom() => stream_info()}
  @type option_callback :: (streams() -> term())
  @type output_av_option :: {atom() | String.t(), av_value() | option_callback()}
  @type source :: Export.t() | StreamRef.t() | atom() | non_neg_integer()
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
  `input/3`, `graph/2`, and `output/4`.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc group: "Construction"
  @doc """
  Builds a command from already-normalized command data.

  This lower-level constructor expects ordered input and output structs. For the
  function callback API, use `FFix.command/3`.

      src = FFix.Command.input("input.mp4")

      FFix.Command.new(
        inputs: [src],
        outputs: [FFix.Command.output(src[:video], "out.mp4", "c:v": :copy)]
      )
  """
  @spec new(keyword()) :: t()
  def new(options) when is_list(options) do
    validate_command_keys!(options)

    graph = normalize_graph!(Keyword.get(options, :graph))
    outputs = normalize_outputs!(Keyword.get(options, :outputs, []))

    {graph, outputs} =
      if graph, do: {graph, outputs}, else: FFix.Command.Build.export_output_sources(outputs)

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
      |> FFix.Command.global(y: true, loglevel: :error)
  """
  @spec global(t(), keyword()) :: t()
  def global(%__MODULE__{global_options: global_options} = command, options)
      when is_list(options) do
    %{command | global_options: global_options ++ options}
  end

  @doc group: "Inputs"
  @doc """
  Builds an input declaration.

  Input options are rendered before `-i`:

      src = FFix.Command.input("input.mp4", ss: "00:00:03")
      src[:video]
      src[:audio]

  Prefer shaping inputs in `FFix.command/3` rather than storing labels on the
  input itself.
  """
  @spec input(Input.source()) :: Input.t()
  def input(source), do: input(source, [])

  @doc group: "Inputs"
  @doc """
  Builds an input with options, or appends an input to a command.

  Called as `input(source, options)`, it returns an `%FFix.Command.Input{}`:

      src = FFix.Command.input("input.mp4", ss: "00:00:03")

  `demuxer:` accepts an `FFix.Demuxer` configuration and `decoders:` accepts a map
  of indexed selectors to `FFix.Decoder` values. Remaining options are raw input
  CLI controls.

  Called as `input(command, source)`, it appends an input without options and
  returns the updated command:

      FFix.Command.new()
      |> FFix.Command.input("input.mp4")
  """
  @spec input(Input.source(), keyword()) :: Input.t()
  @spec input(t(), Input.source()) :: t()
  def input(%__MODULE__{} = command, source), do: input(command, source, [])

  def input(source, options) when is_list(options) do
    validate_endpoint!(source, :input)
    {configuration, raw_options} = Options.split!(options, [:demuxer, :decoders])
    validate_cli_options!(raw_options)

    if Keyword.has_key?(options, :label) do
      raise ArgumentError, "input labels are not supported; name inputs in command inputs instead"
    end

    %Input{
      id: make_ref(),
      source: source,
      options: raw_options,
      demuxer: Keyword.get(configuration, :demuxer),
      decoders: Keyword.get(configuration, :decoders, %{})
    }
  end

  def input(source, options) do
    raise ArgumentError,
          "input options must be a keyword list, got: #{inspect({source, options})}"
  end

  @doc group: "Inputs"
  @doc """
  Appends an input declaration with options to a command.

      FFix.Command.new()
      |> FFix.Command.input("input.mp4", ss: "00:00:03")
  """
  @spec input(t(), Input.source(), keyword()) :: t()
  def input(%__MODULE__{} = command, %Input{} = input, []) do
    %{command | inputs: command.inputs ++ [input]}
  end

  def input(%__MODULE__{} = command, source, options) when is_list(options) do
    %{command | inputs: command.inputs ++ [input(source, options)]}
  end

  def input(%__MODULE__{}, source, options) do
    raise ArgumentError,
          "command input options must be a keyword list, got: #{inspect({source, options})}"
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
  @doc """
  Builds an output declaration from explicit sources.

  Pass graph exports, graph export names/indexes, direct input streams, or
  configured mappings. Sources precede the target, as in `FFix.output/3`.

      src = FFix.Command.input("input.mp4")
      FFix.Command.output([src[:video], src[:audio]], "copy.mp4", c: :copy)

  Bare sources become unconfigured `FFix.Command.Mapping` values. Pass mappings
  directly to configure each output occurrence independently. Pass `muxer:` to
  attach a separate `FFix.Muxer` configuration. Remaining output options are raw
  CLI controls rendered after `-map` entries and before the target.

  Ordered `{name, source_or_mapping}` pairs assign output-local names. Output
  option callbacks receive a map from those names to `t:stream_info/0` values.
  See `FFix.Command.Output` for callback timing and cardinality requirements.
  """
  @spec output(binding() | [binding()], Output.target()) :: Output.t()
  def output(sources, target), do: output(sources, target, [])

  @doc group: "Outputs"
  @doc """
  Builds an output with options, or appends an output to a command.

  Called as `output(sources, target, options)`, it returns an
  `%FFix.Command.Output{}`:

      FFix.Command.output([src[:video], src[:audio]], "copy.mp4", c: :copy)

  Called as `output(command, sources, target)`, it appends an output without
  options and returns the updated command.
  """
  @spec output(binding() | [binding()], Output.target(), keyword()) :: Output.t()
  @spec output(t(), binding() | [binding()], Output.target()) :: t()
  def output(%__MODULE__{} = command, sources, target), do: output(command, sources, target, [])

  def output(sources, target, options) when is_list(options) do
    validate_endpoint!(target, :output)
    {configuration, raw_options} = Options.split!(options, [:muxer])
    validate_cli_options!(raw_options)
    sources = List.wrap(sources)

    if sources == [] do
      raise ArgumentError, "output requires at least one source"
    end

    mappings =
      Enum.map(sources, fn source ->
        case source do
          {name, %Mapping{} = mapping} when is_atom(name) and name not in [nil, true, false] ->
            %{mapping | name: name}

          {name, source} when is_atom(name) and name not in [nil, true, false] ->
            %{Mapping.new(source) | name: name}

          %Mapping{} = mapping ->
            mapping

          source ->
            Mapping.new(source)
        end
      end)

    %Output{
      target: target,
      mappings: mappings,
      muxer: Keyword.get(configuration, :muxer),
      options: raw_options
    }
  end

  def output(sources, target, options) do
    raise ArgumentError,
          "output options must be a keyword list, got: #{inspect({sources, target, options})}"
  end

  @doc group: "Outputs"
  @doc """
  Appends an output declaration with options to a command.

      FFix.Command.new()
      |> FFix.Command.input("input.mp4")
      |> FFix.Command.output(0, "copy.mp4", c: :copy)
  """
  @spec output(t(), binding() | [binding()], Output.target(), keyword()) :: t()
  def output(%__MODULE__{} = command, sources, target, options) when is_list(options) do
    %{command | outputs: command.outputs ++ [output(sources, target, options)]}
  end

  def output(%__MODULE__{}, sources, target, options) do
    raise ArgumentError,
          "command output options must be a keyword list, got: #{inspect({sources, target, options})}"
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
          validate_endpoint!(input.source, :input)
          validate_cli_options!(input.options)

          unless is_nil(input.id) or is_reference(input.id),
            do: raise(ArgumentError, "input identity must be a reference or nil")

          validate_option_callbacks!(input.options, false)
          validate_demuxer!(input)
          validate_decoders!(input)

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

    if map_size(decoders) > 0 do
      configured_options = component_option_names(Map.values(decoders))
      reserved = @codec_selection_options ++ configured_options
      validate_raw_options!(options, reserved, "structured decoding")
    end
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
      Enum.each(output.mappings, fn mapping ->
        unless single_source?(mapping.source, graph) do
          raise ArgumentError,
                "configured encoding requires every output mapping to select one stream; use indexed inputs or filtered exports"
        end
      end)

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
      |> Enum.reduce({%{}, %{video: 0, audio: 0}}, fn {mapping, index}, {streams, counts} ->
        unless single_source?(mapping.source, graph) do
          raise ArgumentError,
                "output option callbacks require every mapping to select one stream; use indexed inputs or filtered exports"
        end

        media = source_media(mapping.source, graph)

        prefix =
          case media do
            :video ->
              "v"

            :audio ->
              "a"

            _unknown ->
              raise ArgumentError,
                    "output option callbacks require known audio/video media for every mapping; use FFix.shape/2 for dynamic filter outputs"
          end

        media_index = Map.fetch!(counts, media)
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

  defp source_media(source, graph) do
    case source do
      %StreamRef{media: media} -> media
      %Export{media: media} -> media
      name_or_index -> Graph.export!(graph, name_or_index).media
    end
  end

  defp validate_encoding!(encoding, source, graph) do
    case encoding do
      nil ->
        :ok

      :copy ->
        if source_node(source, graph).kind == :filter do
          raise ArgumentError, "cannot copy a filtered source; use an encoder"
        end

      %Encoder{} = encoder ->
        validate_component!(encoder)

      other ->
        raise ArgumentError, "invalid encoding configuration: #{inspect(other)}"
    end
  end

  defp single_source?(source, graph) do
    case source_node(source, graph) do
      %{kind: :filter} -> true
      %{kind: :input, input_ref: input_ref} -> single_selector?(input_ref.selector)
    end
  end

  defp source_node(source, graph) do
    case source do
      %StreamRef{plan: plan} ->
        plan

      %Export{ref: ref} ->
        Map.fetch!(graph.nodes, ref.node_id)

      name_or_index ->
        export = Graph.export!(graph, name_or_index)
        Map.fetch!(graph.nodes, export.ref.node_id)
    end
  end

  defp single_selector?(selector) do
    case selector do
      {media, index} when media in [:video, :audio] and is_integer(index) and index >= 0 -> true
      _other -> false
    end
  end

  @doc false
  def validate_decoder!(selector, decoder) do
    unless single_selector?(selector) do
      raise ArgumentError,
            "decoder selector must be {:video, index} or {:audio, index}, got: #{inspect(selector)}"
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
  end

  defp validate_source!(%StreamRef{} = stream, _graph, input_count, input_index_map) do
    resolve_stream_source!(stream, input_count, input_index_map)
    :ok
  end

  defp validate_source!(source, %Graph{} = graph, _input_count, _input_index_map)
       when is_atom(source) or (is_integer(source) and source >= 0) do
    case Graph.export(graph, source) do
      nil -> raise ArgumentError, "command graph has no output #{inspect(source)}"
      _export -> :ok
    end
  end

  defp validate_source!(source, nil, _input_count, _input_index_map)
       when is_atom(source) or (is_integer(source) and source >= 0) do
    raise ArgumentError, "output source #{inspect(source)} requires a command graph"
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

  defp mapped_filter_export(source, %Graph{} = graph)
       when is_atom(source) or (is_integer(source) and source >= 0) do
    graph
    |> Graph.export!(source)
    |> mapped_filter_export(graph)
  end

  defp mapped_filter_export(%StreamRef{}, %Graph{}), do: nil

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
      |> Enum.with_index()
      |> Enum.flat_map(fn {mapping, index} ->
        case mapping.encoding do
          nil -> []
          :copy -> ["-c:#{index}", "copy"]
          %Encoder{} = encoder -> component_to_argv(encoder, Integer.to_string(index))
        end
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

  defp map_source(%StreamRef{} = stream, _graph, _render, input_count, input_index_map) do
    stream
    |> resolve_stream_source!(input_count, input_index_map)
    |> encode_input_ref()
  end

  defp map_source(source, %Graph{} = graph, render, input_count, input_index_map)
       when is_atom(source) or (is_integer(source) and source >= 0) do
    graph
    |> Graph.export!(source)
    |> map_source(graph, render, input_count, input_index_map)
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

  defp resolve_stream_source!(
         %StreamRef{
           plan: %{kind: :input, outputs: 1, input_ref: %InputRef{} = input_ref},
           output: 0,
           media: media
         },
         input_count,
         input_index_map
       ) do
    selector = InputRef.normalize_selector!(input_ref.selector)

    unless media == InputRef.media(selector),
      do: raise(ArgumentError, "input stream media does not match its selector")

    resolve_input_ref!(input_ref, input_count, input_index_map)
  end

  defp resolve_stream_source!(%StreamRef{} = stream, _input_count, _input_index_map) do
    raise ArgumentError,
          "invalid output source: #{inspect(stream)}; only direct input streams can be mapped, export graph outputs instead"
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

  defp encode_option({key, true}), do: ["-#{encode_option_key(key)}"]
  defp encode_option({key, nil}), do: ["-#{encode_option_key(key)}"]

  defp encode_option({key, value}) do
    ["-#{encode_option_key(key)}", encode_option_value(value)]
  end

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

  defp validate_cli_options!(options) do
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
    case selector do
      :input -> to_string(input)
      selector -> "#{input}:#{encode_stream_selector(selector)}"
    end
  end

  defp encode_stream_selector(selector) do
    case selector do
      :video -> "v"
      :audio -> "a"
      {:video, index} -> "v:#{index}"
      {:audio, index} -> "a:#{index}"
      {:raw, selector} -> selector
    end
  end

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
