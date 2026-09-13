Mix.Task.run("app.start")

import FFix

defmodule RunnerEvents do
  alias FFix.Runner.Progress
  alias FFix.Runner.Result

  @duration_seconds 6
  @stats_period 0.5

  def run do
    System.find_executable("ffmpeg") || raise "ffmpeg must be available on PATH"

    cmd =
      command(
        input("testsrc=size=32x32:rate=10:duration=#{@duration_seconds}",
          f: :lavfi,
          re: true
        ),
        fn src -> src[:video] end,
        fn video -> output("-", video: video, f: :null) end,
        global: [nostdin: true, loglevel: "level+info", stats_period: @stats_period]
      )

    IO.puts("command:")
    IO.puts("  #{FFix.to_shell_string(cmd)}")

    run_with_callback(cmd)
    run_as_stream(cmd)
    run_with_discarded_stderr(cmd)
    stream_stdout_and_stderr()
  end

  defp run_with_callback(cmd) do
    parent = self()
    started_at = now()

    result =
      FFix.run!(cmd,
        progress: true,
        stderr: :collect,
        on_event: fn event ->
          print_event("run", started_at, event)
          send(parent, {:run_event, event})
        end
      )

    summarize("run", drain(:run_event), result)
  end

  defp run_as_stream(cmd) do
    started_at = now()

    events =
      cmd
      |> FFix.stream(progress: true, stderr: :collect)
      |> Enum.map(fn event ->
        print_event("stream", started_at, event)
        event
      end)

    summarize("stream", events, exit_result(events))
  end

  defp run_with_discarded_stderr(cmd) do
    parent = self()
    started_at = now()

    result =
      FFix.run!(cmd,
        progress: true,
        stderr: :discard,
        on_event: fn event ->
          print_event("discard", started_at, event)
          send(parent, {:discard_event, event})
        end
      )

    summarize("discard", drain(:discard_event), result)
  end

  defp stream_stdout_and_stderr do
    elixir = System.find_executable("elixir") || raise "elixir must be available on PATH"
    started_at = now()

    events =
      [
        elixir,
        "-e",
        ~S|IO.binwrite(:stdio, "hello stdout"); IO.binwrite(:stderr, "hello stderr")|
      ]
      |> FFix.stream(stdout: :collect, stderr: :collect)
      |> Enum.map(fn event ->
        print_event("stdio", started_at, event)
        event
      end)

    summarize("stdio", events, exit_result(events))
  end

  defp print_event(label, started_at, event) do
    IO.puts("[#{label} +#{elapsed(started_at)}] #{format_event(event)}")
  end

  defp format_event({:stdout, chunk}), do: "stdout #{byte_size(chunk)} bytes #{preview(chunk)}"
  defp format_event({:stderr, chunk}), do: "stderr #{byte_size(chunk)} bytes #{preview(chunk)}"
  defp format_event({:progress, %Progress{} = progress}), do: "progress #{progress(progress)}"

  defp format_event({:exit, %Result{} = result}) do
    "exit status=#{inspect(result.exit_status)}, duration_ms=#{inspect(result.duration_ms)}"
  end

  defp summarize(label, events, %Result{} = result) do
    IO.puts(
      "#{label} summary: #{summary(events)}; last_progress=#{progress(result.last_progress)}"
    )
  end

  defp summary(events) do
    events
    |> Enum.map(&elem(&1, 0))
    |> Enum.frequencies()
    |> Enum.sort()
    |> Enum.map_join(", ", fn {name, count} -> "#{name}=#{count}" end)
  end

  defp progress(nil), do: "nil"

  defp progress(%Progress{} = progress) do
    "status=#{inspect(progress.status)}, frame=#{inspect(progress.frame)}, speed=#{inspect(progress.speed)}"
  end

  defp preview(value) do
    value
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.slice(0, 120)
    |> inspect()
  end

  defp drain(tag, events \\ []) do
    receive do
      {^tag, event} -> drain(tag, [event | events])
    after
      0 -> Enum.reverse(events)
    end
  end

  defp exit_result(events) do
    case List.last(events) do
      {:exit, %Result{} = result} -> result
      other -> raise "expected final exit event, got #{inspect(other)}"
    end
  end

  defp now, do: System.monotonic_time(:millisecond)
  defp elapsed(started_at), do: "#{String.pad_leading(to_string(now() - started_at), 5)}ms"
end

RunnerEvents.run()
