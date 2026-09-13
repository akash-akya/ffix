defmodule FFix.Runner do
  @moduledoc """
  Execute commands, collect results, and observe progress.

  The top-level `FFix.run/2`, `FFix.run!/2`, and `FFix.stream/2` functions use
  this runner. Pass a command built with `FFix.command/2` and choose how to
  handle its output.

  ## Run and handle errors

      case FFix.run(command) do
        {:ok, result} -> IO.puts("Finished in \#{result.duration_ms} ms")
        {:error, error} -> IO.puts(:stderr, error.message)
      end

  Use `run!/2` in scripts when a failed command should raise. For diagnostics,
  `FFix.Runner.Error` carries the execution result and captured stderr.
  `FFix.Runner.Result` describes the available timings, progress, and output fields.

  ## Follow progress

      FFix.stream(command, progress: true)
      |> Enum.each(fn
        {:progress, progress} -> IO.inspect({progress.out_time, progress.speed})
        {:stderr, chunk} -> IO.binwrite(:stderr, chunk)
        {:exit, result} -> IO.inspect(result.exit_status)
        _event -> :ok
      end)

  Execution starts when the stream is enumerated. Use `stream!/2` to raise on a
  failed process exit; plain `stream/2` reports the exit in its result event.
  Halting enumeration cancels the process. Enumerating again starts a new run.

  ## Pipe an image

  Supply bytes with `stdin:` and collect an output written to `:stdout`:

      alias FFix.{Encoder, Filter, Muxer}

      command =
        FFix.input(:stdin, f: "image2pipe")
        |> FFix.video(0)
        |> Filter.scale(w: 640, h: -2)
        |> Encoder.png()
        |> Muxer.mux("image2pipe", :stdout)
        |> FFix.command()

      result = FFix.run!(command, stdin: File.stream!("photo.png", [], 65_536), stdout: :collect)
      File.write!("small.png", result.stdout)

  > #### Collect only what you need {: .warning}
  > `stdout: :collect` and `stderr: :collect` retain their full output in memory.
  > For large media, consume stdout chunks with `stream/2` and keep stdout's
  > default `:discard` capture policy. Live chunks are still emitted.

  ## Choose FFmpeg

  Executable selection follows this order: the `ffmpeg:` runner option,
  `FFMPEG_BIN`, then `ffmpeg` on `PATH`.

      FFix.run(command, ffmpeg: "/usr/local/bin/ffmpeg")

  For an existing argument list, `run/2` also accepts
  `["ffmpeg", "-version"]`. Raw argv uses its own executable and arguments
  unchanged. For setup, see [FFmpeg downloads](https://ffmpeg.org/download.html)
  or the development download task `Mix.Tasks.Ffix.Ffmpeg.Fetch`.
  """

  alias FFix.Command
  alias FFix.Runner.Error
  alias FFix.Runner.Progress
  alias FFix.Runner.Result

  @type stdin_source :: Enumerable.t() | (Collectable.t() -> any())
  @type stdout_mode :: :discard | :collect
  @type stderr_mode :: :discard | :collect | {:tail, pos_integer()}

  @type event ::
          {:stdout, binary()}
          | {:stderr, binary()}
          | {:progress, Progress.t()}
          | {:exit, Result.t()}
          | {:error, Error.t()}

  @type option ::
          {:ffmpeg, String.t()}
          | {:stdin, stdin_source()}
          | {:stdout, stdout_mode()}
          | {:stderr, stderr_mode()}
          | {:progress, boolean()}
          | {:on_event, (event() -> any())}

  @default_stderr_tail 65_536

  @doc """
  Runs a command and returns `{:ok, result}` or `{:error, error}`.

  A zero exit status succeeds. Missing executables and non-zero exits return
  `FFix.Runner.Error`. Process I/O follows `Exile.stream/2` semantics, without
  translation to runner errors. Invalid configuration and exceptions in your
  option callbacks, event handler, or stdin producer propagate to the caller.

  ## Options

  - `:stdin` — an enumerable of bytes, or a function receiving a writable
    `Collectable` sink. For example, `fn sink -> Enum.into(chunks, sink) end`.
  - `:stdout` — `:discard` (default) or `:collect`.
  - `:stderr` — `:discard`, `:collect`, or `{:tail, bytes}`. The default keeps
    the last 65,536 bytes.
  - `:ffmpeg` — executable path/name for command values; see the module guide.
  - `:progress` — parse FFmpeg progress records; defaults to `false`. For command
    values, also adds `-progress pipe:2`. Raw argv must request progress itself.
  - `:on_event` — a function called with every event described in `stream/2`.

  Command execution adds `-hide_banner`, `-nostats`, and `-loglevel level+warning`.
  Override these through command `global:` options. There is no execution deadline;
  use a supervised task when your application needs one.

  Capture policies control retained stdout and stderr, independently of live
  events. Progress fields accumulate until `progress=continue` or `progress=end`,
  independently of stderr capture. Incomplete updates are not emitted.
  """
  @spec run(Command.t() | nonempty_list(String.t()), [option()]) ::
          {:ok, Result.t()} | {:error, Error.t()}
  def run(command, options \\ [])

  def run(command, options) when is_list(options) do
    command
    |> stream(options)
    |> Enum.reduce(nil, fn
      {:exit, result}, _acc -> result_tuple(result)
      {:error, error}, _acc -> {:error, error}
      _event, acc -> acc
    end)
  end

  def run(command, options) do
    raise ArgumentError,
          "runner options must be a keyword list, got: #{inspect({command, options})}"
  end

  @doc "Like `run/2`, returning the result directly and raising `FFix.Runner.Error` on execution failure."
  @spec run!(Command.t() | nonempty_list(String.t()), [option()]) :: Result.t()
  def run!(command, options \\ []) do
    case run(command, options) do
      {:ok, result} -> result
      {:error, %Error{} = error} -> raise error
    end
  end

  @doc """
  Returns a lazy stream of process output, progress, and lifecycle events.

  Accepts the same options as `run/2`. Events are:

  - `{:stdout, chunk}` and `{:stderr, chunk}` — raw bytes.
  - `{:progress, progress}` — a `FFix.Runner.Progress`, when enabled.
  - `{:exit, result}` — process finished; inspect its `exit_status`.
  - `{:error, error}` — the executable could not be found.

  Quiet commands may emit no events until they exit.
  A non-zero exit is still an `:exit` event; use `stream!/2` to raise on failure.
  Early halt cancels and cleans up the child, without emitting an exit event for
  that cancellation. Exile handles process and stdin cleanup, with a 1,000 ms
  timeout per cleanup step. Exceptions from stream consumers propagate normally.

  Consume large streams incrementally. Converting all events to a list retains
  their payloads even when the runner's capture policy is `:discard`.
  """
  @spec stream(Command.t() | nonempty_list(String.t()), [option()]) :: term()
  def stream(command, options \\ [])

  def stream(command, options) when is_list(options) do
    build_stream(command, normalize_options!(options), :plain)
  end

  def stream(command, options) do
    raise ArgumentError,
          "runner options must be a keyword list, got: #{inspect({command, options})}"
  end

  @doc "Like `stream/2`, raising `FFix.Runner.Error` for missing executables or non-zero exits."
  @spec stream!(Command.t() | nonempty_list(String.t()), [option()]) :: term()
  def stream!(command, options \\ [])

  def stream!(command, options) when is_list(options) do
    build_stream(command, normalize_options!(options), :raise)
  end

  def stream!(command, options) do
    raise ArgumentError,
          "runner options must be a keyword list, got: #{inspect({command, options})}"
  end

  defp build_stream(command, options, mode) do
    [command]
    |> Stream.flat_map(fn command ->
      %{command: ff_command, argv: [executable | _args] = argv} =
        build_run_spec!(command, options)

      base_result = %Result{command: ff_command, argv: argv, shell: shell_string(argv)}

      case System.find_executable(executable) do
        nil ->
          reason = "command not found: #{inspect(executable)}"
          [{:error, Error.spawn(reason, base_result)}]

        _path ->
          stream_execution(base_result, options)
      end
    end)
    |> Stream.each(fn event ->
      if options.on_event do
        options.on_event.(event)
      end

      case {mode, event} do
        {:raise, {:error, error}} ->
          raise error

        {:raise, {:exit, %Result{exit_status: status} = result}} when status != 0 ->
          raise Error.exit(result)

        _ ->
          :ok
      end
    end)
  end

  defp stream_execution(base_result, options) do
    started_at = DateTime.utc_now()
    started_ms = System.monotonic_time(:millisecond)

    # An empty enumerable closes stdin when no producer is supplied.
    base_result.argv
    |> Exile.stream(
      input: options.stdin || [],
      stderr: :consume,
      exit_timeout: :infinity,
      cancel_timeout: 1_000,
      ignore_epipe: true
    )
    |> Stream.transform(initial_state(options), fn
      {:exit, {:status, status}}, state ->
        state = %{state | exit_status: status}
        events = finalize_execution(base_result, state, started_at, started_ms)
        {events, state}

      item, state ->
        process_source_item(item, state)
    end)
  end

  defp initial_state(options) do
    %{
      stdout: new_capture(options.stdout),
      stderr: new_capture(options.stderr),
      exit_status: nil,
      progress: options.progress,
      progress_buffer: "",
      progress_fields: %{},
      last_progress: nil
    }
  end

  defp process_source_item({:stdout, chunk}, state) do
    state = %{state | stdout: capture_chunk(state.stdout, chunk)}
    {[{:stdout, chunk}], state}
  end

  defp process_source_item({:stderr, chunk}, state) do
    {events, state} = parse_progress(state, chunk)
    state = %{state | stderr: capture_chunk(state.stderr, chunk)}
    {[{:stderr, chunk} | events], state}
  end

  defp finalize_execution(%Result{} = base_result, state, started_at, started_ms) do
    {trailing_events, state} = parse_progress(state, "\n")

    finished_at = DateTime.utc_now()
    duration_ms = System.monotonic_time(:millisecond) - started_ms

    result = %Result{
      base_result
      | stdout: finalize_capture(state.stdout),
        stderr: finalize_capture(state.stderr),
        last_progress: state.last_progress,
        exit_status: state.exit_status,
        started_at: started_at,
        finished_at: finished_at,
        duration_ms: duration_ms
    }

    trailing_events ++ [{:exit, result}]
  end

  defp result_tuple(%Result{exit_status: 0} = result), do: {:ok, result}
  defp result_tuple(%Result{} = result), do: {:error, Error.exit(result)}

  defp normalize_options!(options) do
    unless Keyword.keyword?(options) do
      raise ArgumentError, "runner options must be a keyword list"
    end

    unknown = Keyword.keys(options) -- [:stdin, :stdout, :stderr, :progress, :on_event, :ffmpeg]

    if unknown != [] do
      raise ArgumentError, "unknown runner options: #{inspect(unknown)}"
    end

    %{
      stdin: normalize_stdin!(Keyword.get(options, :stdin)),
      ffmpeg: normalize_ffmpeg!(Keyword.get(options, :ffmpeg)),
      stdout: normalize_stdout!(Keyword.get(options, :stdout, :discard)),
      stderr: normalize_stderr!(Keyword.get(options, :stderr, {:tail, @default_stderr_tail})),
      progress: normalize_progress!(Keyword.get(options, :progress, false)),
      on_event: normalize_on_event!(Keyword.get(options, :on_event))
    }
  end

  defp normalize_stdin!(input) do
    if is_nil(input) or is_function(input, 1) or Enumerable.impl_for(input) != nil do
      input
    else
      raise ArgumentError, "runner :stdin must be an enumerable or a function with arity 1"
    end
  end

  defp normalize_ffmpeg!(nil), do: nil
  defp normalize_ffmpeg!(name) when is_binary(name) and byte_size(name) > 0, do: name

  defp normalize_ffmpeg!(name) do
    raise ArgumentError, "runner :ffmpeg must be a non-empty string, got: #{inspect(name)}"
  end

  defp normalize_stdout!(:discard), do: :discard
  defp normalize_stdout!(:collect), do: :collect

  defp normalize_stdout!(mode) do
    raise ArgumentError,
          "invalid runner stdout mode #{inspect(mode)}; expected :discard or :collect"
  end

  defp normalize_stderr!(:discard), do: :discard
  defp normalize_stderr!(:collect), do: :collect
  defp normalize_stderr!({:tail, size}) when is_integer(size) and size > 0, do: {:tail, size}

  defp normalize_stderr!(mode) do
    raise ArgumentError,
          "invalid runner stderr mode #{inspect(mode)}; expected :discard, :collect, or {:tail, size}"
  end

  defp normalize_progress!(progress) when is_boolean(progress), do: progress

  defp normalize_progress!(progress) do
    raise ArgumentError,
          "runner :progress must be a boolean, got: #{inspect(progress)}"
  end

  defp normalize_on_event!(nil), do: nil
  defp normalize_on_event!(callback) when is_function(callback, 1), do: callback

  defp normalize_on_event!(callback) do
    raise ArgumentError,
          "runner :on_event must be a function with arity 1, got: #{inspect(callback)}"
  end

  defp build_run_spec!(%Command{} = command, options) do
    [_executable | args] = Command.to_argv(command)
    executable = options.ffmpeg || System.get_env("FFMPEG_BIN") || "ffmpeg"
    defaults = ["-hide_banner", "-nostats", "-loglevel", "level+warning"]

    progress_args =
      if options.progress do
        ["-progress", "pipe:2"]
      else
        []
      end

    %{command: command, argv: [executable | defaults ++ progress_args ++ args]}
  end

  defp build_run_spec!(argv, _options) when is_list(argv) and argv != [] do
    if Enum.all?(argv, &is_binary/1) do
      %{command: nil, argv: argv}
    else
      raise ArgumentError, "runner argv must be a non-empty list of strings"
    end
  end

  defp build_run_spec!(command, _options) do
    raise ArgumentError,
          "runner expects an FFix.Command or argv list, got: #{inspect(command)}"
  end

  defp new_capture(:discard), do: :discard
  defp new_capture(:collect), do: []
  defp new_capture({:tail, _size} = mode), do: {mode, ""}

  defp capture_chunk(:discard, _chunk), do: :discard
  defp capture_chunk(chunks, chunk) when is_list(chunks), do: [chunk | chunks]

  defp capture_chunk({{:tail, size}, current}, chunk) do
    combined = current <> chunk

    if byte_size(combined) > size do
      {{:tail, size}, binary_part(combined, byte_size(combined) - size, size)}
    else
      {{:tail, size}, combined}
    end
  end

  defp finalize_capture(:discard), do: nil

  defp finalize_capture(chunks) when is_list(chunks),
    do: chunks |> Enum.reverse() |> IO.iodata_to_binary()

  defp finalize_capture({{:tail, _size}, data}), do: data

  defp parse_progress(state, chunk) do
    if state.progress do
      pieces = :binary.split(state.progress_buffer <> chunk, "\n", [:global])
      {lines, [buffer]} = Enum.split(pieces, -1)
      state = %{state | progress_buffer: :binary.copy(buffer)}
      Enum.flat_map_reduce(lines, state, &parse_progress_line/2)
    else
      {[], state}
    end
  end

  defp parse_progress_line(line, state) do
    if String.match?(line, ~r/^[A-Za-z0-9_]+=.*$/) do
      [key, value] = String.split(line, "=", parts: 2)
      value = :binary.copy(String.trim(value))
      fields = Map.put(state.progress_fields, :binary.copy(key), value)

      case {key, value} do
        {"progress", status} when status in ["continue", "end"] ->
          progress = build_progress(fields)
          {[{:progress, progress}], %{state | progress_fields: %{}, last_progress: progress}}

        _ ->
          {[], %{state | progress_fields: fields}}
      end
    else
      {[], state}
    end
  end

  defp build_progress(fields) do
    %Progress{
      status: normalize_progress_status(fields["progress"]),
      frame: parse_integer_value(fields["frame"]),
      fps: parse_float_value(fields["fps"]),
      bitrate: normalize_string_value(fields["bitrate"]),
      total_size: parse_integer_value(fields["total_size"]),
      out_time_us: parse_integer_value(fields["out_time_us"]),
      out_time_ms: parse_integer_value(fields["out_time_ms"]),
      out_time: normalize_string_value(fields["out_time"]),
      dup_frames: parse_integer_value(fields["dup_frames"]),
      drop_frames: parse_integer_value(fields["drop_frames"]),
      speed: parse_speed_value(fields["speed"]),
      fields: fields
    }
  end

  defp normalize_progress_status("continue"), do: :continue
  defp normalize_progress_status("end"), do: :end

  defp parse_integer_value(value) do
    case normalize_string_value(value) do
      nil ->
        nil

      value ->
        case Integer.parse(value) do
          {int, ""} -> int
          _ -> nil
        end
    end
  end

  defp parse_float_value(value) do
    case normalize_string_value(value) do
      nil ->
        nil

      value ->
        case Float.parse(value) do
          {float, ""} -> float
          _ -> nil
        end
    end
  end

  defp parse_speed_value(value) do
    value
    |> normalize_string_value()
    |> case do
      nil -> nil
      value -> value |> String.trim_trailing("x") |> parse_float_value()
    end
  end

  defp normalize_string_value(nil), do: nil

  defp normalize_string_value(value) do
    value = String.trim(value)

    if value == "" or value == "N/A" do
      nil
    else
      value
    end
  end

  defp shell_string(argv) do
    Enum.map_join(argv, " ", &shell_escape/1)
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
