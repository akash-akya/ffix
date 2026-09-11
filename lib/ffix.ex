defmodule FFix do
  @moduledoc """
  Explicit, composable FFmpeg inputs, filters, and outputs.

  Build declarations with ordinary Elixir functions. Commands collect input
  dependencies from their outputs; no callback DSL or import macro is required.

      alias FFix.{Encoder, Filter, Muxer}
      source = FFix.input("input.mp4")
      picture = source |> FFix.video() |> Filter.scale(w: 1280, h: -2)
      output = Muxer.mp4(
        [main: Encoder.libx264(picture, crf: 23), sound: FFix.stream_copy(FFix.audio(source))],
        "out.mp4"
      )
      command = FFix.command(output, global: [y: :flag])
      FFix.run(command)

  Inputs own demuxers and decoders; ordered output mappings own encoding or
  packet copy; outputs own muxers. Mapping names are output-local callback keys,
  not filter labels or shared encoder instances. Reusing a mapping requests
  another output occurrence, not distribution of already encoded packets.

  Configure inputs before selecting streams. References capture immutable input
  declarations: reassigning a variable cannot update an existing pipeline. Reuse
  the same declaration to open an input once; separate declarations for the same
  filename remain separate inputs. Conflicting snapshots of one identity fail.

  Produced filter pads require exactly one consumer. Use `Filter.split/2` or
  `Filter.asplit/2` before branching; direct input selections can be reused.
  `FFix.Graph.bind/2` instantiates reusable graph data while retaining every pad,
  terminal branch, and setting.

  Strings carry FFmpeg expressions directly. Raw CLI switches use `:flag` (for
  example `y: :flag`); raw booleans emit `1` or `0`. Serialization escapes
  values at their actual FFmpeg parsing boundaries, independently of shell quoting.

  Generated helpers use recorded metadata for basic checks, without invoking
  FFmpeg or filling in defaults. Generic component names and `filter/4` remain
  escape hatches; FFix does not choose codec implementations or establish local
  availability, hardware usability, or codec/container compatibility.
  """
  @moduledoc groups: [
               "Inputs and outputs",
               "Filtergraphs",
               "Commands",
               "Serialization",
               "Execution",
               "Validation"
             ]

  alias FFix.{Command, Filter, Graph, Runner}
  alias FFix.Command.{Build, Input, Mapping, Output}
  alias FFix.Graph.{Builder, StreamRef, Terminal}

  @type output_media :: :audio | :video | :unknown

  @doc group: "Inputs and outputs"
  @doc "Declares an input. Raw CLI controls precede `-i`; demuxer and decoder configurations belong to this declaration."
  @spec input(Input.source(), list()) :: Input.t()
  def input(source, options \\ []), do: Input.new(source, options)

  @doc group: "Inputs and outputs"
  @doc "Selects one video stream by media-relative index; defaults to the first video stream."
  @spec video(Input.t(), non_neg_integer()) :: StreamRef.t()
  def video(input, index \\ 0), do: Input.select(input, {:video, index})

  @doc group: "Inputs and outputs"
  @doc "Selects one audio stream by media-relative index; defaults to the first audio stream."
  @spec audio(Input.t(), non_neg_integer()) :: StreamRef.t()
  def audio(input, index \\ 0), do: Input.select(input, {:audio, index})

  @doc group: "Inputs and outputs"
  @doc "Selects one subtitle stream for mapping or encoding, not for burning text into video."
  @spec subtitle(Input.t(), non_neg_integer()) :: StreamRef.t()
  def subtitle(input, index \\ 0), do: Input.select(input, {:subtitle, index})

  @doc group: "Inputs and outputs"
  @doc """
  Declares a stream selection without inspecting the input.

  Use `{media, index}` for video, audio, subtitle, data, or attachment streams;
  `{:index, index}` for an absolute input stream index; `:all` or `{media, :all}`
  for broad mappings; and `{:raw, \"s?\"}` for literal FFmpeg selector syntax.
  Broad/optional selections cannot supply known single-stream callback indexes.
  Selecting an existing attachment is not adding a new attachment file.
  """
  @spec select(Input.t(), term()) :: StreamRef.t()
  def select(input, selector), do: Input.select(input, selector)

  @doc group: "Inputs and outputs"
  @doc "Declares packet copy for one mapping. Filtered sources require an encoder; this is not the video filter named copy."
  @spec stream_copy(Command.source()) :: Mapping.t()
  def stream_copy(source), do: Mapping.new(source, :copy)

  @doc group: "Inputs and outputs"
  @doc "Declares an output from ordered streams or named mappings, followed by its target and raw CLI options."
  @spec output(term(), Output.target(), list()) :: Output.t()
  def output(sources, target, options \\ []), do: Output.new(sources, target, options)

  @doc group: "Filtergraphs"
  @doc "Builds an explicit generic filter with an ordered output-media list, without consulting metadata."
  @spec filter(StreamRef.t() | [StreamRef.t()], String.t() | atom(), [output_media()], list()) ::
          StreamRef.t() | [StreamRef.t()] | Terminal.t()
  def filter(inputs, name, output_media, options \\ []),
    do: Filter.filter(inputs, name, output_media, options)

  @doc group: "Filtergraphs"
  @doc "Builds graph data from output references and optional terminal roots/settings."
  @spec graph(keyword()) :: Graph.t()
  def graph(options), do: Builder.graph(options)

  @doc group: "Commands"
  @doc """
  Builds a command from one output or an ordered output list.

  Inputs are inferred by declaration identity in dependency order. Supply an
  explicit ordered `inputs:` list for positional graph references, metadata-only
  inputs, or a required input order. `global:` holds raw command controls;
  `terminals:` retains sink-only roots and `settings:` supplies graph settings.

  Construction and validation never execute deferred output option callbacks.
  Serialization resolves each supplied callback once against final output-local
  absolute and media-relative indexes, without changing stored closures.
  """
  @spec command(Output.t() | [Output.t()], keyword()) :: Command.t()
  def command(outputs, options \\ []), do: Build.command(outputs, options)

  @doc group: "Serialization"
  @doc "Validates and serializes graph data to FFmpeg filtergraph syntax."
  @spec to_filtergraph(Graph.t()) :: String.t()
  def to_filtergraph(%Graph{} = graph), do: Graph.to_filtergraph(graph)

  @doc group: "Serialization"
  @doc "Serializes a command to literal argv; execution's executable selection is separate."
  @spec to_argv(Command.t()) :: [String.t()]
  def to_argv(%Command{} = command), do: Command.to_argv(command)

  @doc group: "Serialization"
  @doc "Serializes shell-escaped text for diagnostics. Prefer literal argv for execution."
  @spec to_shell_string(Command.t()) :: String.t()
  def to_shell_string(%Command{} = command), do: Command.to_shell_string(command)

  @doc group: "Execution"
  @doc "Runs a command and returns an operational success/error tuple. See `FFix.Runner` for capture, executable, and event options."
  @spec run(Command.t() | nonempty_list(String.t()), [Runner.option()]) ::
          {:ok, Runner.Result.t()} | {:error, Runner.Error.t()}
  def run(command, options \\ []), do: Runner.run(command, options)

  @doc group: "Execution"
  @doc "Runs a command and returns its result, raising `FFix.Runner.Error` for operational failures."
  @spec run!(Command.t() | nonempty_list(String.t()), [Runner.option()]) :: Runner.Result.t()
  def run!(command, options \\ []), do: Runner.run!(command, options)

  @doc group: "Execution"
  @doc "Returns lazy execution events. Each enumeration prepares and starts a fresh process."
  @spec stream(Command.t() | nonempty_list(String.t()), [Runner.option()]) :: Enumerable.t()
  def stream(command, options \\ []), do: Runner.stream(command, options)

  @doc group: "Execution"
  @doc "Returns lazy execution events, raising `FFix.Runner.Error` for operational failures."
  @spec stream!(Command.t() | nonempty_list(String.t()), [Runner.option()]) :: Enumerable.t()
  def stream!(command, options \\ []), do: Runner.stream!(command, options)

  @doc group: "Validation"
  @doc "Checks graph/command structure without executing callbacks, probing media, or running FFmpeg."
  @spec validate!(Graph.t() | Command.t()) :: Graph.t() | Command.t()
  def validate!(%Graph{} = graph), do: Builder.validate_graph!(graph)
  def validate!(%Command{} = command), do: Command.validate!(command)
end
