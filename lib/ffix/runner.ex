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
  `FFix.Runner.Result` describes the available timings, logs, and output fields.

  ## Follow progress

      FFix.stream(command, progress: true)
      |> Enum.each(fn
        {:progress, progress} -> IO.inspect({progress.out_time, progress.speed})
        {:log, log} -> IO.puts("[\#{log.level}] \#{log.message}")
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
  alias FFix.Runner.Log
  alias FFix.Runner.Progress
  alias FFix.Runner.Result

  @type stdin_source :: Enumerable.t() | (Collectable.t() -> any())
  @type stdout_mode :: :discard | :collect
  @type stderr_mode :: :discard | :collect | {:tail, pos_integer()}

  @type event ::
          {:start, %{command: Command.t() | nil, argv: [String.t()], shell: String.t()}}
          | {:stdout, binary()}
          | {:stderr, binary()}
          | {:log, Log.t()}
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

  A zero exit status succeeds. Spawn failures, non-zero exits, and process I/O
  failures return `FFix.Runner.Error`. Invalid configuration and exceptions in
  your option callbacks, event handler, or stdin producer propagate to the caller.

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

  Capture policies control retained data, independently of live events. Parsed
  logs share stderr's byte budget, counting raw and message bytes. With bounded
  capture, individual lines and progress records are limited to 65,536 bytes;
  oversized records are omitted. See `FFix.Runner.Result` for truncation flags.
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

  - `{:start, info}` — process started; `info` contains `command`, `argv`, and `shell`.
  - `{:stdout, chunk}` and `{:stderr, chunk}` — raw bytes.
  - `{:log, log}` — a parsed `FFix.Runner.Log`.
  - `{:progress, progress}` — a `FFix.Runner.Progress`, when enabled.
  - `{:exit, result}` — process finished; inspect its `exit_status`.
  - `{:error, error}` — a spawn or process I/O failure.

  `:start` is emitted after a successful spawn, before reading process output.
  A non-zero exit is still an `:exit` event; use `stream!/2` to raise on failure.
  Early halt cancels and cleans up the child, without emitting an exit event for
  that cancellation. Exceptions from stream consumers propagate normally.

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

  @doc "Like `stream/2`, raising `FFix.Runner.Error` for spawn, process I/O, or non-zero exit failures."
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
    Stream.resource(
      fn -> start_execution(command, options) end,
      &next_events/1,
      &cleanup_execution/1
    )
    |> Stream.each(fn event ->
      case event do
        {:application_error, kind, reason, stacktrace} ->
          :erlang.raise(kind, reason, stacktrace)

        _ ->
          emit_events(options.on_event, [event])
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

  defp start_execution(command, options) do
    %{command: ff_command, argv: argv} = build_run_spec!(command, options)
    base_result = %Result{command: ff_command, argv: argv, shell: shell_string(argv)}

    case start_process(argv) do
      {:ok, process} ->
        %{
          process: process,
          writer: start_writer(process, options.stdin),
          base_result: base_result,
          state: initial_state(options),
          started_at: DateTime.utc_now(),
          started_ms: System.monotonic_time(:millisecond),
          phase: :start
        }

      {:error, reason} ->
        %{phase: :error, error: Error.spawn(format_spawn_reason(reason), base_result)}
    end
  end

  # Exile starts the OS process asynchronously. The call is a startup barrier;
  # unlinking lets read/await failures become data rather than killing the caller.
  defp start_process(argv) do
    previous_trap = Process.flag(:trap_exit, true)

    try do
      case Exile.Process.start_link(argv, stderr: :consume) do
        {:ok, process} ->
          Process.unlink(process.pid)

          case process_call(fn -> Exile.Process.os_pid(process) end) do
            {:error, reason} ->
              Process.demonitor(process.monitor_ref, [:flush])
              flush_process_exit(process.pid)
              {:error, reason}

            _started ->
              flush_process_exit(process.pid)
              {:ok, process}
          end

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error in MatchError ->
        case error.term do
          {:error, reason} -> {:error, reason}
          _ -> reraise error, __STACKTRACE__
        end
    after
      Process.flag(:trap_exit, previous_trap)
    end
  end

  defp flush_process_exit(pid) do
    receive do
      {:EXIT, ^pid, _reason} -> :ok
    after
      0 -> :ok
    end
  end

  defp process_call(callback) do
    callback.()
  catch
    :exit, reason -> {:error, reason}
  end

  defp next_events(%{phase: :done} = execution), do: {:halt, execution}

  defp next_events(%{phase: :error, error: error} = execution) do
    {[{:error, error}], %{execution | phase: :done}}
  end

  defp next_events(%{phase: :start} = execution) do
    {[start_event(execution.base_result)], %{execution | phase: :read}}
  end

  defp next_events(%{phase: :read} = execution) do
    case process_call(fn -> Exile.Process.read_any(execution.process) end) do
      {:ok, item} ->
        {events, state} = process_source_item(item, execution.state)
        {events, %{execution | state: state}}

      :eof ->
        {[], %{execution | phase: :finish}}

      {:error, reason} ->
        {events, execution} = io_failure(execution, reason)
        {events, %{execution | phase: :cancel}}
    end
  end

  defp next_events(%{phase: :cancel} = execution), do: {:halt, execution}

  defp next_events(%{phase: :finish} = execution) do
    writer_result = await_writer(execution.writer)
    exit_result = process_call(fn -> Exile.Process.await_exit(execution.process, :infinity) end)

    state =
      case exit_result do
        {:ok, status} -> %{execution.state | exit_status: status}
        {:error, _reason} -> execution.state
      end

    execution = %{execution | phase: :done, state: state}

    case {writer_result, exit_result} do
      {{:application_error, _, _, _} = event, _} ->
        {[event], execution}

      {{:error, reason}, _} ->
        io_failure(execution, reason)

      {:ok, {:error, reason}} ->
        io_failure(execution, reason)

      {:ok, {:ok, status}} ->
        state = %{execution.state | exit_status: status}

        {events, _result} =
          finalize_execution(
            execution.base_result,
            state,
            execution.started_at,
            execution.started_ms
          )

        {events, execution}
    end
  end

  defp io_failure(execution, reason) do
    {events, result} =
      finalize_execution(
        execution.base_result,
        execution.state,
        execution.started_at,
        execution.started_ms
      )

    diagnostics = Enum.drop(events, -1)
    {diagnostics ++ [{:error, Error.io(format_spawn_reason(reason), result)}], execution}
  end

  defp cleanup_execution(%{phase: :done}), do: :ok
  defp cleanup_execution(%{phase: :error}), do: :ok

  defp cleanup_execution(execution) do
    if execution.writer do
      Task.shutdown(execution.writer, :brutal_kill)
    end

    # Cancellation is not an execution failure and must not replace a consumer exception.
    process_call(fn -> Exile.Process.await_exit(execution.process, 1_000) end)
    :ok
  end

  defmodule InputSink do
    @moduledoc false
    defstruct [:process, :error_ref]

    defimpl Collectable do
      def into(sink) do
        collector = fn
          acc, {:cont, chunk} ->
            result =
              try do
                Exile.Process.write(sink.process, chunk)
              catch
                :exit, reason -> {:error, reason}
              end

            case result do
              :ok -> acc
              {:error, reason} -> throw({sink.error_ref, reason})
            end

          acc, :done ->
            acc

          _acc, :halt ->
            :ok
        end

        {:ok, collector}
      end
    end
  end

  defp start_writer(process, nil) do
    process_call(fn -> Exile.Process.close_stdin(process) end)
    nil
  end

  defp start_writer(process, input) do
    Task.async(fn ->
      error_ref = make_ref()
      sink = %InputSink{process: process, error_ref: error_ref}

      result =
        try do
          case process_call(fn -> Exile.Process.change_pipe_owner(process, :stdin, self()) end) do
            :ok ->
              if is_function(input, 1) do
                input.(sink)
              else
                Enum.into(input, sink)
              end

              :ok

            {:error, reason} ->
              {:error, reason}
          end
        catch
          :throw, {^error_ref, reason} -> {:error, reason}
          kind, reason -> {:application_error, kind, reason, __STACKTRACE__}
        after
          process_call(fn -> Exile.Process.close_stdin(process) end)
        end

      if result != :ok do
        process_call(fn -> Exile.Process.kill(process, :sigkill) end)
      end

      result
    end)
  end

  defp await_writer(nil), do: :ok
  defp await_writer(writer), do: Task.await(writer, :infinity)

  defp start_event(%Result{} = base_result) do
    {:start, %{command: base_result.command, argv: base_result.argv, shell: base_result.shell}}
  end

  defp initial_state(options) do
    %{
      stdout: new_capture(options.stdout),
      stderr: new_capture(options.stderr),
      exit_status: nil,
      stderr_parser: new_stderr_parser(options),
      logs: new_logs(options.stderr),
      last_progress: nil
    }
  end

  defp process_source_item({:stdout, chunk}, state) do
    chunk = IO.iodata_to_binary(chunk)
    events = [{:stdout, chunk}]
    state = %{state | stdout: capture_chunk(state.stdout, chunk)}
    {events, state}
  end

  defp process_source_item({:stderr, chunk}, state) do
    chunk = IO.iodata_to_binary(chunk)
    {stderr_parser, parsed_events} = parse_stderr_chunk(state.stderr_parser, chunk)
    {logs, last_progress} = merge_parsed_events(parsed_events, state.logs, state.last_progress)

    state = %{
      state
      | stderr: capture_chunk(state.stderr, chunk),
        stderr_parser: stderr_parser,
        logs: logs,
        last_progress: last_progress
    }

    {[{:stderr, chunk}] ++ parsed_events, state}
  end

  defp finalize_execution(%Result{} = base_result, state, started_at, started_ms) do
    {stderr_parser, trailing_events} = finalize_stderr_parser(state.stderr_parser)
    {logs, last_progress} = merge_parsed_events(trailing_events, state.logs, state.last_progress)

    finished_at = DateTime.utc_now()
    duration_ms = System.monotonic_time(:millisecond) - started_ms

    result = %Result{
      base_result
      | stdout: finalize_capture(state.stdout),
        stderr: finalize_capture(state.stderr),
        logs: Enum.map(:queue.to_list(logs.queue), fn {log, _bytes} -> log end),
        logs_truncated: logs.truncated,
        diagnostics_truncated: stderr_parser.truncated,
        last_progress: last_progress,
        exit_status: state.exit_status,
        started_at: started_at,
        finished_at: finished_at,
        duration_ms: duration_ms
    }

    {trailing_events ++ [{:exit, result}], result}
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

  defp new_stderr_parser(options) do
    limit =
      case options.stderr do
        :collect -> :infinity
        _ -> @default_stderr_tail
      end

    %{
      buffer: "",
      dropping_line: false,
      progress: options.progress,
      progress_fields: %{},
      progress_bytes: 0,
      dropping_progress: false,
      limit: limit,
      truncated: false
    }
  end

  defp parse_stderr_chunk(%{buffer: buffer} = state, chunk) do
    pieces = :binary.split(buffer <> chunk, "\n", [:global])
    {lines, [next_buffer]} = Enum.split(pieces, -1)
    state = %{state | buffer: ""}

    {state, events} =
      Enum.reduce(lines, {state, []}, fn line, {state, events} ->
        {state, line_events} = complete_stderr_line(state, line)
        {state, Enum.reverse(line_events, events)}
      end)

    state =
      if state.dropping_line or exceeds_limit?(byte_size(next_buffer), state.limit) do
        %{truncate_record(state) | buffer: "", dropping_line: true}
      else
        %{state | buffer: :binary.copy(next_buffer)}
      end

    {state, Enum.reverse(events)}
  end

  defp complete_stderr_line(state, line) do
    if state.dropping_line or exceeds_limit?(byte_size(line), state.limit) do
      {%{truncate_record(state) | dropping_line: false}, []}
    else
      parse_stderr_line(state, String.trim_trailing(line, "\r"))
    end
  end

  defp truncate_record(state) do
    %{
      state
      | truncated: true,
        progress_fields: %{},
        progress_bytes: 0,
        dropping_progress: state.progress
    }
  end

  defp exceeds_limit?(_size, :infinity), do: false
  defp exceeds_limit?(size, limit), do: size > limit

  defp finalize_stderr_parser(%{buffer: ""} = state), do: {state, []}

  defp finalize_stderr_parser(%{buffer: buffer} = state) do
    complete_stderr_line(%{state | buffer: ""}, buffer)
  end

  defp parse_stderr_line(state, ""), do: {state, []}

  defp parse_stderr_line(state, line) do
    if state.progress and progress_line?(line) do
      [key, value] = String.split(line, "=", parts: 2)
      parse_progress_field(state, :binary.copy(key), :binary.copy(String.trim(value)))
    else
      case parse_log_line(line) do
        nil -> {state, []}
        log -> {state, [{:log, log}]}
      end
    end
  end

  defp parse_progress_field(state, key, value) do
    previous_bytes =
      case Map.fetch(state.progress_fields, key) do
        {:ok, previous} -> byte_size(key) + byte_size(previous)
        :error -> 0
      end

    bytes = state.progress_bytes - previous_bytes + byte_size(key) + byte_size(value)

    state =
      if state.dropping_progress or exceeds_limit?(bytes, state.limit) do
        truncate_record(state)
      else
        %{
          state
          | progress_fields: Map.put(state.progress_fields, key, value),
            progress_bytes: bytes
        }
      end

    if key == "progress" do
      events =
        if state.dropping_progress do
          []
        else
          [{:progress, build_progress(state.progress_fields)}]
        end

      {%{state | progress_fields: %{}, progress_bytes: 0, dropping_progress: false}, events}
    else
      {state, []}
    end
  end

  defp progress_line?(line) do
    String.match?(line, ~r/^[A-Za-z0-9_]+=.*$/)
  end

  defp parse_log_line(line) do
    case Regex.run(
           ~r/(?:^|\s)\[(panic|fatal|error|warning|info|verbose|debug|trace)\]\s*(.*)$/,
           line,
           capture: :all_but_first
         ) do
      [level, message] ->
        %Log{
          level: String.to_atom(level),
          message: :binary.copy(if(message == "", do: line, else: message)),
          raw: :binary.copy(line)
        }

      _ ->
        nil
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
  defp normalize_progress_status(status), do: normalize_string_value(status)

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

  defp new_logs(mode) do
    limit =
      case mode do
        :collect -> :infinity
        :discard -> 0
        {:tail, size} -> size
      end

    %{queue: :queue.new(), bytes: 0, limit: limit, truncated: false}
  end

  defp retain_log(logs, log) do
    bytes = byte_size(log.raw) + byte_size(log.message)
    trim_logs(%{logs | queue: :queue.in({log, bytes}, logs.queue), bytes: logs.bytes + bytes})
  end

  defp trim_logs(logs) do
    if exceeds_limit?(logs.bytes, logs.limit) do
      {{:value, {_log, bytes}}, queue} = :queue.out(logs.queue)
      trim_logs(%{logs | queue: queue, bytes: logs.bytes - bytes, truncated: true})
    else
      logs
    end
  end

  defp merge_parsed_events(events, logs, last_progress) do
    Enum.reduce(events, {logs, last_progress}, fn
      {:log, %Log{} = log}, {logs, last_progress} ->
        {retain_log(logs, log), last_progress}

      {:progress, %Progress{} = progress}, {logs, _last_progress} ->
        {logs, progress}
    end)
  end

  defp emit_events(nil, _events), do: :ok

  defp emit_events(callback, events) do
    Enum.each(events, callback)
  end

  defp format_spawn_reason(reason) when is_binary(reason), do: reason
  defp format_spawn_reason(reason), do: inspect(reason)

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
