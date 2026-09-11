defmodule FFix.Runner do
  @moduledoc """
  Thin execution layer for `%FFix.Command{}` values or raw argv lists.

  The core library models commands as data. `FFix.Runner` is the boundary that
  starts an OS process and turns stdout, stderr, logs, progress, and exit status
  into Elixir data.

  ## Collected Execution

      {:ok, result} =
        FFix.run(command,
          stdout: :discard,
          stderr: :collect
        )

      result.exit_status
      result.stderr

  `run/2` returns `{:ok, result}` for exit status `0` and `{:error, error}` for
  non-zero exits, spawn failures, or I/O failures. `run!/2` returns the result or raises
  `FFix.Runner.Error`.

  ## Streaming Events

      FFix.stream(command, progress: true, stderr: :collect)
      |> Enum.each(fn
        {:log, log} -> IO.puts("[\#{log.level}] \#{log.message}")
        {:progress, progress} -> IO.inspect(progress.status)
        {:exit, result} -> IO.inspect(result.exit_status)
        _event -> :ok
      end)

  `stream/2` is lazy and emits:

    * `{:start, info}`
    * `{:stdout, chunk}`
    * `{:stderr, chunk}`
    * `{:log, %FFix.Runner.Log{}}`
    * `{:progress, %FFix.Runner.Progress{}}`
    * `{:exit, %FFix.Runner.Result{}}`
    * `{:error, %FFix.Runner.Error{}}` for spawn or I/O failures

  Each enumeration serializes and executes afresh. Start is emitted after spawn,
  before reading output. Early halt cancels and reaps the child without reporting
  its cancellation status. Application callbacks and consumers retain their
  original exceptions. There is no execution deadline.

  When running a `%FFix.Command{}`, the runner prepends a few quiet-by-default execution flags:

    * `-hide_banner`
    * `-nostats`
    * `-loglevel level+warning`

  Later command options still win, so callers can override log level or stats in
  the command itself.
  """
  @moduledoc groups: [
               "Collected execution",
               "Streaming execution"
             ]

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

  @doc group: "Collected execution"
  @doc """
  Runs a command and returns a collected result tuple.

  Options:

    * `:stdin` - enumerable input for process stdin
    * `:stdout` - `:discard` or `:collect`
    * `:stderr` - `:discard`, `:collect`, or `{:tail, bytes}`
    * `:ffmpeg` - executable for Command values; defaults to `FFMPEG_BIN`, then `ffmpeg`
    * `:progress` - parses stderr progress; also adds `-progress pipe:2` for Command values
    * `:on_event` - callback invoked with each emitted event

  By default stdout is discarded and only 65,536 trailing stderr bytes are kept.
  Parsed logs use the stderr byte budget (counting raw and message bytes);
  `:discard` retains no logs. Lines and progress records are limited to 65,536
  bytes unless stderr is explicitly `:collect`, which retains all diagnostics.
  Oversized records are dropped; result truncation flags report these omissions.
  Capture policies never suppress live stdout, stderr, log, or progress events.
  Progress parsing is opt-in, including for raw argv, which is always executed
  literally without FFmpeg flags or executable substitution.

      FFix.run(command, stderr: :collect)
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

  @doc group: "Collected execution"
  @doc """
  Runs a command and raises `FFix.Runner.Error` on operational failure.
  """
  @spec run!(Command.t() | nonempty_list(String.t()), [option()]) :: Result.t()
  def run!(command, options \\ []) do
    case run(command, options) do
      {:ok, result} -> result
      {:error, %Error{} = error} -> raise error
    end
  end

  @doc group: "Streaming execution"
  @doc """
  Runs a command as a lazy event stream.

  This is useful for progress reporting, log streaming, or large stdout streams
  that should not be collected into memory.

      FFix.stream(command, progress: true, stdout: :collect)
      |> Enum.each(fn
        {:stdout, chunk} -> IO.binwrite(chunk)
        {:progress, progress} -> IO.inspect(progress.frame)
        {:exit, result} -> IO.inspect(result.exit_status)
        _event -> :ok
      end)
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

  @doc group: "Streaming execution"
  @doc """
  Runs a command as a lazy event stream and raises `FFix.Runner.Error` on
  operational failure. Early halt is cancellation, not a failed exit.
  """
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
