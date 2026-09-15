defmodule FFix.Discovery.Exec do
  @moduledoc false

  alias FFix.Discovery.Error

  def run(arguments, options) do
    options =
      Keyword.validate!(options,
        ffmpeg: System.get_env("FFMPEG_BIN") || "ffmpeg",
        timeout: 10_000,
        max_output: 8_388_608
      )

    timeout = options[:timeout]
    max_output = options[:max_output]

    unless timeout == :infinity or (is_integer(timeout) and timeout >= 0) do
      raise ArgumentError, "discovery :timeout must be a non-negative integer or :infinity"
    end

    unless is_integer(max_output) and max_output >= 0 do
      raise ArgumentError, "discovery :max_output must be a non-negative integer"
    end

    with {:ok, executable} <- executable(options[:ffmpeg]) do
      argv = [executable, "-hide_banner", "-v", "quiet" | arguments]
      task = Task.async(fn -> capture(argv, max_output) end)
      await(task, argv, timeout)
    end
  end

  defp executable(name) do
    case System.find_executable(name) do
      nil ->
        {:error,
         %Error{
           reason: :executable_not_found,
           message: "FFmpeg executable not found: #{inspect(name)}"
         }}

      path ->
        {:ok, path}
    end
  end

  defp await(task, argv, timeout) do
    result = Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill)

    case result do
      {:ok, result} ->
        result

      nil ->
        {:error, %Error{reason: :timeout, message: "FFmpeg discovery timed out", argv: argv}}

      {:exit, reason} ->
        {:error,
         %Error{
           reason: :command_failed,
           message: "FFmpeg process exited: #{inspect(reason)}",
           argv: argv
         }}
    end
  end

  defp capture(argv, limit) do
    # Exile's watcher terminates the OS child when a timed-out task is killed.
    stream =
      Exile.stream(argv,
        stderr: :redirect_to_stdout,
        env: [{"LC_ALL", "C"}],
        exit_timeout: 1_000,
        ignore_epipe: true
      )

    {status, chunks} = Enum.reduce_while(stream, {[], limit}, &collect/2)
    output = chunks |> Enum.reverse() |> IO.iodata_to_binary()
    result(status, %{argv: argv, output: output})
  rescue
    error in [Exile.Process.Error, Exile.Stream.AbnormalExit, MatchError] ->
      {:error, %Error{reason: :command_failed, message: Exception.message(error), argv: argv}}
  end

  defp collect(event, {chunks, remaining}) do
    case event do
      {:exit, status} ->
        {:halt, {status, chunks}}

      chunk when byte_size(chunk) <= remaining ->
        {:cont, {[chunk | chunks], remaining - byte_size(chunk)}}

      chunk ->
        captured_chunk = binary_part(chunk, 0, remaining)
        {:halt, {:output_limit, [captured_chunk | chunks]}}
    end
  end

  defp result(status, capture) do
    case status do
      {:status, 0} ->
        {:ok, capture}

      :output_limit ->
        {:error,
         %Error{
           reason: :output_limit,
           message: "FFmpeg metadata exceeds output limit",
           argv: capture.argv,
           output: capture.output
         }}

      _other ->
        {:error,
         %Error{
           reason: :command_failed,
           message: "FFmpeg metadata command failed",
           argv: capture.argv,
           output: capture.output,
           exit_status: status
         }}
    end
  end
end
