defmodule FFix.Command do
  @moduledoc """
  The inputs, outputs, and options for one FFmpeg invocation.

  Usually, build a command with `FFix.command/2`: it collects input dependencies
  from your outputs. This module also supports constructing and editing command
  data directly, which is useful for tools that already manage explicit inputs
  and filtergraphs.

  ## FFmpeg options and their scope

  Put options on the thing they configure:

  | Setting | Where it belongs | Example |
  | --- | --- | --- |
  | Invocation-wide control | `FFix.command/2`, under `global:` | `n: :flag` |
  | Input seeking or limits | `FFix.input/2` | `ss: 30` |
  | Decoding | `FFix.Decoder` | `threads: 2` |
  | Output encoding | `FFix.Encoder` | `crf: 23` |
  | Container settings | `FFix.Muxer` | `movflags: [:faststart]` |
  | Output duration or metadata | `FFix.output/3` | `t: 10` |

  Demuxer and muxer helpers take general input/output controls in
  `input_options:` and `output_options:` respectively.

  General CLI option names are atoms or strings without the leading dash.
  Use `:flag` for a valueless switch; `true` and `false` are values, rendered as
  `1` and `0`. Lists of values are joined with `+`. Strings can carry FFmpeg's
  compound syntax, and floats are written as decimal numbers.

      source = FFix.input("interview.mp4", ss: 30)
      output = FFix.output(FFix.audio(source, 0), "excerpt.wav", t: 10)
      FFix.command(output, global: [n: :flag])

  Prefer encoder and muxer helpers for codec and format settings: they apply
  the right stream scopes. If using raw scoped options, write the full name,
  such as `"metadata:s:a:0"`. FFix rejects raw controls that conflict with
  structured settings or change the mapping layout those settings depend on.
  Conflict checks ignore stream scopes.
  Raw option names can repeat where FFmpeg allows it; structured component
  options must be specified once.

  ## Explicit construction

  For input ordering alone, use `FFix.command(outputs, inputs: ordered_inputs)`.

      alias FFix.Command
      source = FFix.input("interview.mp4")
      output = FFix.output(FFix.audio(source, 0), "interview.wav")

      command =
        Command.new(global: [n: :flag])
        |> Command.add_input(source)
        |> Command.add_output(output)

      FFix.to_argv(command)

  This path uses exactly the supplied inputs, in order. Repeated input
  declarations are rejected. Selections must use the same input configuration
  as the supplied declaration; see `FFix.Command.Input` for input reuse.

  Commands may be incomplete while you assemble them. Call `validate!/1` to
  check the finished command, or serialize it with `to_argv/1`.
  """

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

  @doc "Returns an empty command for use with `add_input/2`, `graph/2`, and `add_output/2`."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Builds command data from `global:`, `inputs:`, `graph:`, and `outputs:`.

  Inputs and outputs are ordered lists of declarations. All options are optional
  during construction. For dependency collection, use `FFix.command/2` instead.

  Filtered outputs use export handles from the supplied graph's `exports` field:

      source = FFix.input("interview.mp4")
      graph = FFix.Graph.parse!("[0:v:0]hflip[picture]")
      output = FFix.output(hd(graph.exports), "mirrored.mp4")
      FFix.Command.new(inputs: [source], graph: graph, outputs: [output])

  Export handles belong to their graph. Use `graph[:picture]` for ordinary filter
  composition through `FFix.command/2`, which collects the whole referenced graph.
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

  @doc "Appends invocation-wide options, rendered before inputs. For example, `global(command, n: :flag)`."
  @spec global(t(), [option()]) :: t()
  def global(%__MODULE__{} = command, options) when is_list(options) do
    %{command | global_options: command.global_options ++ options}
  end

  @doc "Appends an input created with `FFix.input/2` or a `FFix.Demuxer` helper."
  @spec add_input(t(), Input.t()) :: t()
  def add_input(%__MODULE__{} = command, %Input{} = input) do
    %{command | inputs: command.inputs ++ [input]}
  end

  @doc "Sets the command's filtergraph. See `new/1` for mapping its exports to outputs."
  @spec graph(t(), Graph.t()) :: t()
  def graph(%__MODULE__{} = command, %Graph{} = graph), do: %{command | graph: graph}

  @doc "Appends an output created with `FFix.output/3` or a `FFix.Muxer` helper."
  @spec add_output(t(), Output.t()) :: t()
  def add_output(%__MODULE__{} = command, %Output{} = output) do
    %{command | outputs: command.outputs ++ [output]}
  end

  @doc """
  Checks the command's connections, input declarations, and option scopes.

  Returns the original command or raises `ArgumentError`. Output callback
  layouts are checked here; callback values are evaluated during serialization.
  FFmpeg checks files, installed components, and format compatibility at execution.
  """
  @spec validate!(t()) :: t()
  def validate!(%__MODULE__{} = command) do
    Prepare.command!(command)
    command
  end

  @doc "Validates and returns FFmpeg arguments as a list, beginning with `\"ffmpeg\"`. See `FFix.to_argv/1`."
  @spec to_argv(t()) :: [String.t()]
  def to_argv(%__MODULE__{} = command) do
    command
    |> Prepare.command!()
    |> Prepare.resolve_options!()
    |> Render.to_argv()
  end

  @doc "Returns shell-quoted command text for logs and debugging. See `FFix.to_shell_string/1`."
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
