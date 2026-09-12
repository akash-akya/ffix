defmodule FFix do
  @moduledoc """
  Build and run FFmpeg commands in Elixir.

  Use FFix to convert media, extract tracks, choose codecs and containers, or
  process audio and video with filters. Start with inputs and outputs; add a
  filter pipeline when you need to change the picture or sound.

  You will need [FFmpeg](https://ffmpeg.org/download.html) on your `PATH` to run
  these examples. See `FFix.Runner` to choose another executable.

  ## Your first command

  Extract the first audio track from an interview into a WAV file:

      command =
        FFix.input("interview.mp4")
        |> FFix.audio(0)
        |> FFix.output("interview.wav")
        |> FFix.command()

      FFix.run!(command)

  An input file can contain several streams: video, audio tracks, subtitles,
  and more. `audio(input, 0)` selects the first audio stream; indexes start at
  zero. FFmpeg chooses the WAV format and its default encoder from the filename.

  There are two deliberate steps at the end. An **output** describes what to
  write and where. A **command** brings the outputs and their inputs together.
  Building either is just preparation; `run!/2` starts FFmpeg.

  ## Choose a codec and a container

  An encoder compresses the media. A muxer packages streams into a container,
  such as MP4 or Matroska. Here, AAC is the audio codec and MP4 is the container
  used for the `.m4a` file:

      alias FFix.{Encoder, Muxer}

      command =
        FFix.input("interview.wav")
        |> FFix.audio(0)
        |> Encoder.aac(b: "128k")
        |> Muxer.mp4("interview.m4a")
        |> FFix.command()

      FFix.run!(command)

  `b: "128k"` sets the audio bitrate to 128 kbit/s. An encoder can be used directly
  on an input stream: filtering is optional. See `FFix.Encoder` for quality and
  bitrate settings, and `FFix.Muxer` for format-specific options.

  ## Copy streams without re-encoding

  When the existing codecs suit the destination, stream copy is faster and
  preserves the encoded media. This example puts an MP4's first video track
  and all its audio tracks into a Matroska file:

      source = FFix.input("interview.mp4")

      output =
        FFix.output(
          [
            FFix.stream_copy(FFix.video(source, 0)),
            FFix.stream_copy(FFix.audio(source, :all))
          ],
          "interview.mkv"
        )

      FFix.command(output) |> FFix.run!()

  `:all` selects every stream of that media type. See `stream_copy/1` for format
  compatibility and `FFix.Command.Input` for selecting optional tracks.

  ## Add a filter

  Filters work on decoded pictures or sound. Apply them before choosing the
  output encoder. Here we resize a video while copying its audio:

      alias FFix.{Encoder, Filter, Muxer}
      source = FFix.input("interview.mp4")

      picture =
        source
        |> FFix.video(0)
        |> Filter.scale(w: 1280, h: -2)
        |> Encoder.libx264(crf: 23, preset: "medium")

      output =
        Muxer.mp4(
          [picture, FFix.stream_copy(FFix.audio(source, 0))],
          "interview-small.mp4",
          movflags: [:faststart]
        )

      FFix.command(output) |> FFix.run!()

  `h: -2` keeps the aspect ratio and gives the height an even number of pixels.
  `crf` controls video quality; lower values mean higher quality and usually
  larger files. `faststart` helps an MP4 begin playing before its download finishes.
  This example assumes an audio track compatible with MP4; use `FFix.Encoder.aac/2`
  instead of stream copy when you need AAC audio.

  Explore `FFix.Filter` for cropping, overlays, audio processing, and combining streams.

  ## Write several outputs

  Pass an ordered list of outputs to `command/2`. Reuse an input declaration to
  read it once, even when outputs use different encoders or settings.

  This video-only example scales once, then splits the filtered pictures into
  a full-size rendition and a small preview:

      alias FFix.{Encoder, Filter, Muxer}
      source = FFix.input("interview.mp4")

      [main, preview] =
        source
        |> FFix.video(0)
        |> Filter.scale(w: 1280, h: -2)
        |> Filter.split(outputs: 2)

      main_output = Muxer.mp4(Encoder.libx264(main, crf: 20), "main.mp4")

      preview_output =
        preview
        |> Filter.scale(w: 320, h: -2)
        |> Encoder.libx264(crf: 28)
        |> Muxer.mp4("preview.mp4")

      FFix.command([main_output, preview_output]) |> FFix.run!()

  A filtered stream needs a split to feed two branches. Direct input streams
  can be reused as they are. Outputs can also use entirely different inputs.
  They still run in one FFmpeg process; use separate commands when jobs need
  independent cancellation or retries.

  ## Inspect, run, and learn more

  Inspect a command before executing it:

      FFix.to_shell_string(command)
      FFix.to_argv(command)

  `run/2` returns `{:ok, result}` or `{:error, error}`. `run!/2` returns the result
  or raises on execution failure. Both accept runner options such as
  `ffmpeg: "/usr/local/bin/ffmpeg"` and `stderr: :collect`.

  - `FFix.Command.Input`: stream selection and input options.
  - `FFix.Command.Output`: mapping order and named output-option callbacks.
  - `FFix.Demuxer` and `FFix.Decoder`: explicit input formats and decoding settings.
  - `FFix.Graph`: parse and reuse filtergraphs.
  - `FFix.Runner`: progress events, piping media, and handling failures.
  - `FFix.Discovery`: find the codecs, formats, and filters in your FFmpeg build.

  The [FFmpeg command guide](https://ffmpeg.org/ffmpeg.html) is a useful companion
  when you need the meaning of a particular FFmpeg option.
  """
  @moduledoc groups: ["Building", "Inspecting", "Running"]

  alias FFix.{Command, Filter, Graph, Runner, Selection}
  alias FFix.Command.{Build, Input, Mapping, Output}
  alias FFix.Graph.{Builder, StreamRef, Terminal}

  @type output_media :: :audio | :video | :unknown
  @type stream_index :: non_neg_integer() | :all
  @type video_option :: Input.selection_option() | {:attached_pictures, boolean()}

  @doc group: "Building"
  @doc """
  Declares a media source and its input options.

      source = FFix.input("interview.mp4", ss: 30)

  Input options apply before reading this source. Here, `ss` seeks to 30 seconds.
  For file, URL, and pipe sources, see `FFix.Command.Input.new/2`.
  """
  @spec input(Input.source(), list()) :: Input.t()
  def input(source, options \\ []), do: Input.new(source, options)

  @doc group: "Building"
  @doc """
  Selects a video stream by zero-based video index, or all video streams with `:all`.

      FFix.video(source, 0)
      FFix.video(source, :all, optional: true)
      FFix.video(source, 0, attached_pictures: false)

  Options:

  - `:optional` — allow a missing match when mapping an output; defaults to `false`.
  - `:attached_pictures` — include cover art and thumbnails in matching; defaults
    to `true`. Set it to `false` to use FFmpeg's `V` selector.

  An indexed, required selection can feed a filter. `:all` and optional selections
  go directly to outputs. See `FFix.Command.Input` for the selection rules.
  """
  @spec video(Input.t(), stream_index(), [video_option()]) :: StreamRef.t() | Selection.t()
  def video(input, index, options \\ []), do: Input.select_media(input, :video, index, options)

  @doc group: "Building"
  @doc """
  Selects an audio stream by zero-based audio index, or all audio streams with `:all`.

      FFix.audio(source, 0)
      FFix.audio(source, :all, optional: true)

  `optional: true` lets FFmpeg omit missing matches from an output. One audio
  stream may contain several channels; stereo is usually one stream.
  See `FFix.Command.Input` for selection examples.
  """
  @spec audio(Input.t(), stream_index(), [Input.selection_option()]) ::
          StreamRef.t() | Selection.t()
  def audio(input, index, options \\ []), do: Input.select_media(input, :audio, index, options)

  @doc group: "Building"
  @doc """
  Selects a subtitle track by zero-based subtitle index, or all subtitle tracks with `:all`.

  Use `optional: true` to allow a missing track. These selections add subtitle
  streams to outputs. To draw subtitles onto the video itself, use
  `FFix.Filter.subtitles/2`.
  """
  @spec subtitle(Input.t(), stream_index(), [Input.selection_option()]) ::
          StreamRef.t() | Selection.t()
  def subtitle(input, index, options \\ []),
    do: Input.select_media(input, :subtitle, index, options)

  @doc group: "Building"
  @doc """
  Selects by absolute stream index, `:all`, or an FFmpeg stream specifier.

      FFix.select(source, 3)
      FFix.select(source, :all)
      FFix.select(source, "a:m:language:eng", optional: true)

  An absolute index counts every stream in the file. Prefer `video/3`, `audio/3`,
  and `subtitle/3` when selecting by media type. Strings and optional selections
  are output queries; use an indexed media helper to select a filter input.
  See `FFix.Command.Input` and FFmpeg's
  [stream specifiers](https://ffmpeg.org/ffmpeg.html#Stream-specifiers).
  """
  @spec select(Input.t(), Input.selector(), [Input.selection_option()]) ::
          StreamRef.t() | Selection.t()
  def select(input, selector, options \\ []), do: Input.select(input, selector, options)

  @doc group: "Building"
  @doc """
  Copies the selected encoded streams into an output, saving encoding time and quality loss.

      audio = source |> FFix.audio(:all) |> FFix.stream_copy()
      FFix.output(audio, "audio.mka")

  > #### Check the destination format {: .warning}
  > The output container must support the copied codecs. Stream copy also
  > requires an unfiltered source: after filtering, choose an encoder instead.
  """
  @spec stream_copy(Command.source()) :: Mapping.t()
  def stream_copy(source), do: Mapping.new(source, :copy)

  @doc group: "Building"
  @doc """
  Declares an output from one source or an ordered list, a target, and output options.

      FFix.output([video, audio], "interview.mp4", t: 30)

  Bare streams use FFmpeg's default encoding. Apply `FFix.Encoder` or
  `stream_copy/1` to choose it explicitly. `FFix.Muxer` helpers provide
  format-specific options. See `FFix.Command.Output` for named mappings and callbacks.
  """
  @spec output(term(), Output.target(), list()) :: Output.t()
  def output(sources, target, options \\ []), do: Output.new(sources, target, options)

  @doc group: "Building"
  @doc """
  Builds a filter with an explicit name and ordered output media.

  Use the named `FFix.Filter` helpers for common filters. See
  `FFix.Filter.filter/4` for custom names and output shapes.
  """
  @spec filter(StreamRef.t() | [StreamRef.t()], String.t() | atom(), [output_media()], list()) ::
          StreamRef.t() | [StreamRef.t()] | Terminal.t()
  def filter(inputs, name, output_media, options \\ []),
    do: Filter.filter(inputs, name, output_media, options)

  @doc group: "Building"
  @doc """
  Groups filter outputs into a reusable graph.

      graph = FFix.graph(outputs: [main: video, sound: audio])
      graph[:main]

  Supply `output:` for a single unnamed output or `outputs:` for an ordered list,
  optionally named. `terminals:` includes sink branches and `settings:` accepts
  `sws_flags`. See `FFix.Graph` for templates, binding, and parsing.
  """
  @spec graph(keyword()) :: Graph.t()
  def graph(options), do: Builder.graph(options)

  @doc group: "Building"
  @doc """
  Assembles and validates one output or an ordered list of outputs as a command.

      FFix.command(output)
      FFix.command([main_output, preview_output], global: [n: :flag])

  The command collects the inputs used by its outputs. Reusing an input
  declaration opens it once; separate declarations open separate inputs.

  Options:

  - `:global` — FFmpeg options for the whole invocation.
  - `:inputs` — a complete, ordered input list. Use this for positional graph
    inputs, additional metadata inputs, or a specific input order. Include every
    input used by the outputs, with the same configuration.
  - `:terminals` — sink branches to execute alongside the outputs.
  - `:settings` — graph settings, currently `sws_flags`.

  With explicit `inputs:`, selections follow their input declarations even when
  the order changes. Configure sources before selecting streams; see
  `FFix.Command.Input` for examples. Output callbacks run during serialization.

  > #### Overwriting files {: .warning}
  > `global: [y: :flag]` permits replacing existing output files.
  > Use `global: [n: :flag]` to refuse overwrites.

  For direct construction and manipulation of command data, see `FFix.Command`.
  """
  @spec command(Output.t() | [Output.t()], keyword()) :: Command.t()
  def command(outputs, options \\ []), do: Build.command(outputs, options)

  @doc group: "Inspecting"
  @doc "Validates a graph and returns its FFmpeg filtergraph text. See `FFix.Graph.to_filtergraph/1`."
  @spec to_filtergraph(Graph.t()) :: String.t()
  def to_filtergraph(%Graph{} = graph), do: Graph.to_filtergraph(graph)

  @doc group: "Inspecting"
  @doc """
  Returns a command as an argument list beginning with `\"ffmpeg\"`.

  Prefer this list when passing a command to another process library. Arguments
  are escaped for FFmpeg and do not need shell quoting. The runner chooses its
  executable separately through `FFix.Runner.run/2` options.
  """
  @spec to_argv(Command.t()) :: [String.t()]
  def to_argv(%Command{} = command), do: Command.to_argv(command)

  @doc group: "Inspecting"
  @doc "Returns a shell-quoted command for logs and debugging. Use `to_argv/1` for process execution."
  @spec to_shell_string(Command.t()) :: String.t()
  def to_shell_string(%Command{} = command), do: Command.to_shell_string(command)

  @doc group: "Running"
  @doc """
  Runs a command, returning `{:ok, result}` or `{:error, error}`.

  See `FFix.Runner.run/2` for executable selection, input/output capture, and
  progress options, and `FFix.Runner.Result` for result fields.
  """
  @spec run(Command.t() | nonempty_list(String.t()), [Runner.option()]) ::
          {:ok, Runner.Result.t()} | {:error, Runner.Error.t()}
  def run(command, options \\ []), do: Runner.run(command, options)

  @doc group: "Running"
  @doc "Like `run/2`, returning the result directly and raising `FFix.Runner.Error` on execution failure."
  @spec run!(Command.t() | nonempty_list(String.t()), [Runner.option()]) :: Runner.Result.t()
  def run!(command, options \\ []), do: Runner.run!(command, options)

  @doc group: "Running"
  @doc "Returns a lazy stream of execution events. See `FFix.Runner.stream/2` for progress and piping examples."
  @spec stream(Command.t() | nonempty_list(String.t()), [Runner.option()]) :: Enumerable.t()
  def stream(command, options \\ []), do: Runner.stream(command, options)

  @doc group: "Running"
  @doc "Like `stream/2`, raising `FFix.Runner.Error` on execution failure."
  @spec stream!(Command.t() | nonempty_list(String.t()), [Runner.option()]) :: Enumerable.t()
  def stream!(command, options \\ []), do: Runner.stream!(command, options)

  @doc group: "Inspecting"
  @doc """
  Checks graph or command structure and returns the original value.

  Raises `ArgumentError` for invalid connections or configuration. Validation
  checks the instructions; FFmpeg checks actual files and available codecs when
  the command runs. Deferred output option values are checked during serialization.
  """
  @spec validate!(Graph.t() | Command.t()) :: Graph.t() | Command.t()
  def validate!(%Graph{} = graph), do: Builder.validate_graph!(graph)
  def validate!(%Command{} = command), do: Command.validate!(command)
end
