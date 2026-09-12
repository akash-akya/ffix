defmodule FFix.Command do
  @moduledoc """
  Canonical representation of a full ffmpeg command.

  A command stores global options, ordered inputs, an optional filtergraph, and
  ordered outputs. It is still just data until `FFix.to_argv/1`, `FFix.run/1`, or
  another boundary function serializes it.

  Prefer `FFix.command/2` for the output-first API. Use this module directly
  when constructing or transforming `%FFix.Command{}` values in smaller steps.
  Supply inputs explicitly and map direct input selections or canonical
  `graph.exports` handles with their graph. This layer does not infer dependencies.
  Captured input snapshots must match the supplied declarations.

      input = FFix.Command.Input.new("input.mp4", ss: "00:00:03")
      video = FFix.video(input, :all)

      FFix.Command.new(
        global: [y: :flag],
        inputs: [input],
        outputs: [FFix.Command.Output.new(FFix.stream_copy(video), "out.mp4")]
      )
      |> FFix.to_argv()

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
  alias __MODULE__.Prepare
  alias __MODULE__.Render
  alias FFix.Graph
  alias FFix.Graph.Export
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

  @type t :: %__MODULE__{
          global_options: [option()],
          inputs: [Input.t()],
          graph: Graph.t() | nil,
          outputs: [Output.t()]
        }

  defstruct global_options: [], inputs: [], graph: nil, outputs: []

  @doc group: "Construction"
  @doc "Returns an empty command for step-by-step construction."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc group: "Construction"
  @doc """
  Builds a command from ordered input and output declarations.

  Filtered mappings require canonical exports from the explicit `:graph`.
  No dependency inference occurs. Commands may be incomplete until `validate!/1`
  or serialization; neither construction nor validation evaluates callbacks.
  """
  @spec new(keyword()) :: t()
  def new(options) when is_list(options) do
    validate_keys!(options, [:global, :inputs, :graph, :outputs])
    inputs = declarations!(Keyword.get(options, :inputs, []), Input, :inputs)
    outputs = declarations!(Keyword.get(options, :outputs, []), Output, :outputs)
    graph = Keyword.get(options, :graph)
    global = Keyword.get(options, :global, [])

    unless is_nil(graph) or is_struct(graph, Graph) do
      raise ArgumentError, "invalid command graph: #{inspect(graph)}"
    end

    unless is_list(global) do
      raise ArgumentError, "command global must be a keyword list"
    end

    %__MODULE__{global_options: global, inputs: inputs, graph: graph, outputs: outputs}
  end

  @doc group: "Construction"
  @doc "Appends global ffmpeg options, rendered before inputs."
  @spec global(t(), [option()]) :: t()
  def global(%__MODULE__{} = command, options) when is_list(options) do
    %{command | global_options: command.global_options ++ options}
  end

  @doc group: "Inputs"
  @doc "Appends an existing input declaration to a low-level command."
  @spec add_input(t(), Input.t()) :: t()
  def add_input(%__MODULE__{} = command, %Input{} = input) do
    %{command | inputs: command.inputs ++ [input]}
  end

  @doc group: "Filtergraph"
  @doc "Sets the filtergraph for a command."
  @spec graph(t(), Graph.t()) :: t()
  def graph(%__MODULE__{} = command, %Graph{} = graph), do: %{command | graph: graph}

  @doc group: "Outputs"
  @doc "Appends an existing output declaration to a low-level command."
  @spec add_output(t(), Output.t()) :: t()
  def add_output(%__MODULE__{} = command, %Output{} = output) do
    %{command | outputs: command.outputs ++ [output]}
  end

  @doc group: "Validation"
  @doc """
  Checks inputs, graph ownership, mappings, encoding scopes, and callback layouts.

  Returns the original command without resolving its stored input identities,
  running ffmpeg, probing media, or evaluating deferred option callbacks.
  Callback results are checked during serialization.
  """
  @spec validate!(t()) :: t()
  def validate!(%__MODULE__{} = command) do
    Prepare.command!(command)
    command
  end

  @doc group: "Serialization"
  @doc "Serializes a command to literal ffmpeg argv, the canonical execution boundary."
  @spec to_argv(t()) :: [String.t()]
  def to_argv(%__MODULE__{} = command) do
    command
    |> Prepare.command!()
    |> Prepare.resolve_options!()
    |> Render.to_argv()
  end

  @doc group: "Serialization"
  @doc "Serializes a command as a shell-escaped string for logs and debugging."
  @spec to_shell_string(t()) :: String.t()
  def to_shell_string(%__MODULE__{} = command) do
    command |> to_argv() |> Enum.map_join(" ", &Render.shell_escape/1)
  end

  @doc false
  def validate_keys!(options, allowed) do
    unless Keyword.keyword?(options) do
      raise ArgumentError, "command options must be a keyword list"
    end

    keys = Keyword.keys(options)

    if length(keys) != length(Enum.uniq(keys)) do
      raise ArgumentError, "duplicate command option"
    end

    unknown = keys -- allowed

    if unknown != [] do
      raise ArgumentError, "unknown command keys: #{inspect(unknown)}"
    end
  end

  defp declarations!(values, module, key) do
    unless is_list(values) do
      raise ArgumentError, "command #{key} must be a list"
    end

    Enum.each(values, fn value ->
      unless is_struct(value, module) do
        raise ArgumentError, "invalid command #{key}: #{inspect(value)}"
      end
    end)

    values
  end
end
