defmodule FF.Runner do
  @moduledoc """
  Thin execution layer for `%FF.Command{}` values or raw argv lists.

  The core library models commands as data. `FF.Runner` is the boundary that
  starts an OS process and turns stdout, stderr, logs, progress, and exit status
  into Elixir data.

  ## Collected Execution

      {:ok, result} =
        FF.run(command,
          stdout: :discard,
          stderr: :collect
        )

      result.exit_status
      result.stderr

  `run/2` returns `{:ok, result}` for exit status `0` and `{:error, error}` for
  non-zero exits or spawn failures. `run!/2` returns the result or raises
  `FF.Runner.Error`.

  ## Streaming Events

      FF.stream(command, progress: true, stderr: :collect)
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
    * `{:log, %FF.Runner.Log{}}`
    * `{:progress, %FF.Runner.Progress{}}`
    * `{:exit, %FF.Runner.Result{}}`

  When running `ffmpeg`, the runner prepends a few quiet-by-default execution flags:

    * `-hide_banner`
    * `-nostats`
    * `-loglevel level+warning`

  Later command options still win, so callers can override log level or stats in
  the command itself.
  """

  alias FF.Command
  alias FF.Runner.Error
  alias FF.Runner.Log
  alias FF.Runner.Progress
  alias FF.Runner.Result

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

  @type option ::
          {:stdin, stdin_source()}
          | {:stdout, stdout_mode()}
          | {:stderr, stderr_mode()}
          | {:progress, boolean()}
          | {:on_event, (event() -> any())}

  @default_stderr_tail 65_536

  @doc """
  Runs a command and returns a collected result tuple.

  Options:

    * `:stdin` - enumerable input for process stdin
    * `:stdout` - `:discard` or `:collect`
    * `:stderr` - `:discard`, `:collect`, or `{:tail, bytes}`
    * `:progress` - when `true`, adds `-progress pipe:2` for ffmpeg commands
    * `:on_event` - callback invoked with each emitted event

  By default stdout is discarded and only the trailing stderr is kept.

      FF.run(command, stderr: :collect)
  """
  @spec run(Command.t() | nonempty_list(String.t()), [option()]) ::
          {:ok, Result.t()} | {:error, Error.t()}
  def run(command, options \\ [])

  def run(command, options) when is_list(options) do
    case prepare_execution(command, options) do
      {:ok, base_result, normalized_options} -> execute_run(base_result, normalized_options)
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  def run(command, options) do
    raise ArgumentError,
          "runner options must be a keyword list, got: #{inspect({command, options})}"
  end

  @doc """
  Runs a command and raises `FF.Runner.Error` on spawn failure or non-zero exit.
  """
  @spec run!(Command.t() | nonempty_list(String.t()), [option()]) :: Result.t()
  def run!(command, options \\ []) do
    case run(command, options) do
      {:ok, result} -> result
      {:error, %Error{} = error} -> raise error
    end
  end

  @doc """
  Runs a command as a lazy event stream.

  This is useful for progress reporting, log streaming, or large stdout streams
  that should not be collected into memory.

      FF.stream(command, progress: true, stdout: :collect)
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
    case prepare_execution(command, options) do
      {:ok, base_result, normalized_options} ->
        build_stream(base_result, normalized_options, :plain)

      {:error, %Error{} = error} ->
        raise error
    end
  end

  def stream(command, options) do
    raise ArgumentError,
          "runner options must be a keyword list, got: #{inspect({command, options})}"
  end

  @doc """
  Runs a command as a lazy event stream and raises on non-zero exit.
  """
  @spec stream!(Command.t() | nonempty_list(String.t()), [option()]) :: term()
  def stream!(command, options \\ [])

  def stream!(command, options) when is_list(options) do
    case prepare_execution(command, options) do
      {:ok, base_result, normalized_options} ->
        build_stream(base_result, normalized_options, :raise)

      {:error, %Error{} = error} ->
        raise error
    end
  end

  def stream!(command, options) do
    raise ArgumentError,
          "runner options must be a keyword list, got: #{inspect({command, options})}"
  end

  defp prepare_execution(command, options) do
    options = normalize_options!(options)
    %{command: ff_command, argv: argv} = build_run_spec!(command)
    argv = apply_runtime_defaults(argv, options)
    shell = shell_string(argv)

    base_result = %Result{command: ff_command, argv: argv, shell: shell}

    case resolve_executable(List.first(argv)) do
      nil ->
        {:error, Error.spawn(~s(command not found: #{inspect(List.first(argv))}), base_result)}

      _path ->
        {:ok, base_result, options}
    end
  end

  defp execute_run(%Result{} = base_result, options) do
    try do
      started_at = DateTime.utc_now()
      started_ms = System.monotonic_time(:millisecond)
      emit_events(options.on_event, [start_event(base_result)])

      state =
        base_result
        |> source_stream(options)
        |> Enum.reduce(initial_state(options), fn item, state ->
          {events, state} = process_source_item(item, state)
          emit_events(options.on_event, events)
          state
        end)

      {final_events, result} = finalize_execution(base_result, state, started_at, started_ms)
      emit_events(options.on_event, final_events)
      result_tuple(result)
    rescue
      error in MatchError ->
        case error.term do
          {:error, reason} -> {:error, Error.spawn(format_spawn_reason(reason), base_result)}
          _other -> reraise error, __STACKTRACE__
        end
    end
  end

  defp build_stream(%Result{} = base_result, options, mode) when mode in [:plain, :raise] do
    start_event = start_event(base_result)

    base_result
    |> source_stream(options)
    |> Stream.transform(
      fn ->
        %{
          state: initial_state(options),
          started_at: DateTime.utc_now(),
          started_ms: System.monotonic_time(:millisecond),
          pending_events: [start_event]
        }
      end,
      fn item, acc ->
        {events, state} = process_source_item(item, acc.state)

        case item do
          {:exit, _status} ->
            {final_events, result} =
              finalize_execution(base_result, state, acc.started_at, acc.started_ms)

            emitted_events = acc.pending_events ++ events ++ final_events
            emit_events(options.on_event, emitted_events)

            case {mode, result.exit_status} do
              {:plain, _status} ->
                {emitted_events, %{acc | state: state, pending_events: []}}

              {:raise, 0} ->
                {emitted_events, %{acc | state: state, pending_events: []}}

              {:raise, _status} ->
                raise Error.exit(result)
            end

          _other ->
            emitted_events = acc.pending_events ++ events
            emit_events(options.on_event, emitted_events)
            {emitted_events, %{acc | state: state, pending_events: []}}
        end
      end,
      fn _acc -> :ok end
    )
  end

  defp source_stream(%Result{argv: argv}, options) do
    argv
    |> Exile.stream(stderr: exile_stderr_mode(options.stderr), input: options.stdin)
    |> Stream.map(&normalize_source_item/1)
  end

  defp start_event(%Result{} = base_result) do
    {:start, %{command: base_result.command, argv: base_result.argv, shell: base_result.shell}}
  end

  defp initial_state(options) do
    %{
      stdout: new_capture(options.stdout),
      stderr: new_capture(options.stderr),
      exit_status: nil,
      stderr_parser: new_stderr_parser(),
      logs: [],
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

  defp process_source_item({:exit, {:status, status}}, state) do
    {[], %{state | exit_status: status}}
  end

  defp process_source_item({:exit, :epipe}, state) do
    {[], %{state | exit_status: :epipe}}
  end

  defp finalize_execution(%Result{} = base_result, state, started_at, started_ms) do
    {_stderr_parser, trailing_events} = finalize_stderr_parser(state.stderr_parser)
    {logs, last_progress} = merge_parsed_events(trailing_events, state.logs, state.last_progress)

    finished_at = DateTime.utc_now()
    duration_ms = System.monotonic_time(:millisecond) - started_ms

    result = %Result{
      base_result
      | stdout: finalize_capture(state.stdout),
        stderr: finalize_capture(state.stderr),
        logs: Enum.reverse(logs),
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
    unknown = Keyword.keys(options) -- [:stdin, :stdout, :stderr, :progress, :on_event]

    if unknown != [] do
      raise ArgumentError, "unknown runner options: #{inspect(unknown)}"
    end

    %{
      stdin: Keyword.get(options, :stdin),
      stdout: normalize_stdout!(Keyword.get(options, :stdout, :discard)),
      stderr: normalize_stderr!(Keyword.get(options, :stderr, {:tail, @default_stderr_tail})),
      progress: normalize_progress!(Keyword.get(options, :progress, false)),
      on_event: normalize_on_event!(Keyword.get(options, :on_event))
    }
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

  defp build_run_spec!(%Command{} = command) do
    %{command: command, argv: Command.to_argv(command)}
  end

  defp build_run_spec!(argv) when is_list(argv) and argv != [] do
    if Enum.all?(argv, &is_binary/1) do
      %{command: nil, argv: argv}
    else
      raise ArgumentError, "runner argv must be a non-empty list of strings"
    end
  end

  defp build_run_spec!(command) do
    raise ArgumentError,
          "runner expects an FF.Command or argv list, got: #{inspect(command)}"
  end

  defp apply_runtime_defaults([executable | args] = argv, options) do
    if ffmpeg_executable?(executable) do
      defaults =
        ["-hide_banner", "-nostats", "-loglevel", "level+warning"] ++
          if(options.progress, do: ["-progress", "pipe:2"], else: [])

      [executable | defaults ++ args]
    else
      argv
    end
  end

  defp ffmpeg_executable?(executable) when is_binary(executable) do
    Path.basename(executable) == "ffmpeg"
  end

  defp resolve_executable(nil), do: nil

  defp resolve_executable(executable) when is_binary(executable),
    do: System.find_executable(executable)

  defp normalize_source_item(chunk) when is_binary(chunk), do: {:stdout, chunk}
  defp normalize_source_item(item), do: item

  defp exile_stderr_mode(:discard), do: :disable
  defp exile_stderr_mode(:collect), do: :consume
  defp exile_stderr_mode({:tail, _size}), do: :consume

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

  defp new_stderr_parser do
    %{buffer: "", progress_fields: %{}}
  end

  defp parse_stderr_chunk(%{buffer: buffer} = state, chunk) do
    text = buffer <> chunk
    pieces = String.split(text, "\n")
    {lines, [next_buffer]} = Enum.split(pieces, -1)
    state = %{state | buffer: next_buffer}

    Enum.reduce(lines, {state, []}, fn line, {state, events} ->
      {state, line_events} = parse_stderr_line(state, String.trim_trailing(line, "\r"))
      {state, events ++ line_events}
    end)
  end

  defp finalize_stderr_parser(%{buffer: ""} = state), do: {state, []}

  defp finalize_stderr_parser(%{buffer: buffer} = state) do
    parse_stderr_line(%{state | buffer: ""}, String.trim_trailing(buffer, "\r"))
  end

  defp parse_stderr_line(state, ""), do: {state, []}

  defp parse_stderr_line(%{progress_fields: progress_fields} = state, line) do
    if progress_line?(line) do
      [key, value] = String.split(line, "=", parts: 2)
      progress_fields = Map.put(progress_fields, key, String.trim(value))

      if key == "progress" do
        progress = build_progress(progress_fields)
        {%{state | progress_fields: %{}}, [{:progress, progress}]}
      else
        {%{state | progress_fields: progress_fields}, []}
      end
    else
      case parse_log_line(line) do
        nil -> {state, []}
        log -> {state, [{:log, log}]}
      end
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
          message: if(message == "", do: line, else: message),
          raw: line
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

  defp merge_parsed_events(events, logs, last_progress) do
    Enum.reduce(events, {logs, last_progress}, fn
      {:log, %Log{} = log}, {logs, last_progress} ->
        {[log | logs], last_progress}

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
