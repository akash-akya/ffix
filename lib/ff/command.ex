defmodule FF.Command do
  @moduledoc """
  Canonical representation of a full ffmpeg command.
  """

  alias __MODULE__.Input
  alias __MODULE__.Output
  alias FF.Graph
  alias FF.Graph.Export
  alias FF.Graph.InputRef

  @type option :: {atom() | String.t(), term()}
  @type source :: Export.t() | InputRef.t()

  @type t :: %__MODULE__{
          global_options: [option()],
          inputs: [Input.t()],
          graph: Graph.t() | nil,
          outputs: [Output.t()],
          metadata: map()
        }

  defstruct global_options: [], inputs: [], graph: nil, outputs: [], metadata: %{}

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec global(t(), keyword()) :: t()
  def global(%__MODULE__{global_options: global_options} = command, options) when is_list(options) do
    %{command | global_options: global_options ++ options}
  end

  @spec input(t(), Input.source(), keyword()) :: t()
  def input(%__MODULE__{inputs: inputs} = command, source, options \\ []) when is_list(options) do
    input = %Input{source: source, options: options}
    %{command | inputs: inputs ++ [input]}
  end

  @spec input_stream(non_neg_integer(), InputRef.selector()) :: InputRef.t()
  def input_stream(index, selector) when is_integer(index) and index >= 0 do
    %InputRef{input: index, selector: selector}
  end

  @spec graph(t(), Graph.t()) :: t()
  def graph(%__MODULE__{} = command, %Graph{} = graph) do
    %{command | graph: graph}
  end

  @spec output(t(), Output.target(), source() | [source()], keyword()) :: t()
  def output(%__MODULE__{outputs: outputs} = command, target, sources, options \\ [])
      when is_list(options) do
    output = %Output{target: target, sources: List.wrap(sources), options: options}
    %{command | outputs: outputs ++ [output]}
  end

  @spec validate!(t()) :: t()
  def validate!(%__MODULE__{} = command) do
    if command.outputs == [] do
      raise ArgumentError, "command requires at least one output"
    end

    input_count = length(command.inputs)

    if command.graph do
      command.graph
      |> FF.validate!()
      |> validate_graph_inputs!(input_count)
    end

    Enum.each(command.outputs, fn %Output{sources: sources} ->
      if sources == [] do
        raise ArgumentError, "output requires at least one source"
      end

      Enum.each(sources, &validate_source!(&1, command.graph, input_count))
    end)

    command
  end

  @spec to_argv(t()) :: [String.t()]
  def to_argv(%__MODULE__{} = command) do
    command = validate!(command)
    render = if command.graph, do: FF.Graph.Render.render(command.graph)

    ["ffmpeg"] ++
      encode_options(command.global_options) ++
      Enum.flat_map(command.inputs, &input_to_argv/1) ++
      graph_to_argv(render) ++
      Enum.flat_map(command.outputs, &output_to_argv(&1, command.graph, render))
  end

  @spec to_shell_string(t()) :: String.t()
  def to_shell_string(%__MODULE__{} = command) do
    command
    |> to_argv()
    |> Enum.map_join(" ", &shell_escape/1)
  end

  defp validate_source!(%Export{} = export, nil, _input_count) do
    raise ArgumentError, "graph export #{inspect(export.name || export.ref)} requires a graph"
  end

  defp validate_source!(%Export{} = export, %Graph{} = graph, _input_count) do
    unless Enum.member?(graph.exports, export) do
      raise ArgumentError,
            "graph export #{inspect(export.name || export.ref)} is not exported by the command graph"
    end
  end

  defp validate_source!(%InputRef{} = input_ref, _graph, input_count) do
    validate_input_ref!(input_ref, input_count)
  end

  defp validate_source!(source, _graph, _input_count) do
    raise ArgumentError, "invalid output source: #{inspect(source)}"
  end

  defp input_to_argv(%Input{source: source, options: options}) do
    encode_options(options) ++ ["-i", encode_input_source(source)]
  end

  defp graph_to_argv(nil), do: []
  defp graph_to_argv(%{graph: graph}), do: ["-filter_complex", graph]

  defp output_to_argv(%Output{target: target, sources: sources, options: options}, graph, render) do
    # Outputs read in terms of graph exports and input streams, but argv still needs
    # ffmpeg's explicit `-map` syntax at the boundary.
    Enum.flat_map(sources, fn source -> ["-map", map_source(source, graph, render)] end) ++
      encode_options(options) ++
      [encode_output_target(target)]
  end

  defp map_source(%InputRef{} = input_ref, _graph, _render) do
    encode_input_ref(input_ref)
  end

  defp map_source(%Export{} = export, %Graph{} = graph, render) do
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

  defp validate_graph_inputs!(%Graph{} = graph, input_count) do
    Enum.each(Map.values(graph.nodes), fn
      %{kind: :input, input_ref: %InputRef{} = input_ref} -> validate_input_ref!(input_ref, input_count)
      _node -> :ok
    end)

    graph
  end

  defp validate_input_ref!(%InputRef{input: input}, input_count) do
    if input < input_count do
      :ok
    else
      raise ArgumentError, "input #{input} is not declared in the command"
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
  defp encode_option_value(value) when is_float(value), do: :erlang.float_to_binary(value, [:compact])
  defp encode_option_value(value) when is_atom(value), do: Atom.to_string(value)
  defp encode_option_value(value) when is_list(value), do: Enum.map_join(value, "+", &encode_option_value/1)
  defp encode_option_value(value) when is_binary(value), do: value

  defp encode_input_source(:stdin), do: "pipe:0"
  defp encode_input_source({:pipe, fd}) when is_integer(fd) and fd >= 0, do: "pipe:#{fd}"
  defp encode_input_source({:url, url}) when is_binary(url), do: url
  defp encode_input_source(source) when is_binary(source), do: source

  defp encode_output_target(:stdout), do: "pipe:1"
  defp encode_output_target({:pipe, fd}) when is_integer(fd) and fd >= 0, do: "pipe:#{fd}"
  defp encode_output_target({:url, url}) when is_binary(url), do: url
  defp encode_output_target(target) when is_binary(target), do: target

  defp encode_input_ref(%InputRef{input: input, selector: :video}), do: "#{input}:v"
  defp encode_input_ref(%InputRef{input: input, selector: :audio}), do: "#{input}:a"
  defp encode_input_ref(%InputRef{input: input, selector: {:video, stream}}), do: "#{input}:v:#{stream}"
  defp encode_input_ref(%InputRef{input: input, selector: {:audio, stream}}), do: "#{input}:a:#{stream}"
  defp encode_input_ref(%InputRef{input: input, selector: {:raw, selector}}), do: "#{input}:#{selector}"

  defp shell_escape(""), do: "''"

  defp shell_escape(argument) do
    if String.match?(argument, ~r|^[A-Za-z0-9_@%+=:,./-]+$|) do
      argument
    else
      "'" <> String.replace(argument, "'", ~S('"'"')) <> "'"
    end
  end
end
