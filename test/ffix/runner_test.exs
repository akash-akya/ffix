defmodule FFix.RunnerTest do
  use ExUnit.Case, async: true

  alias FFix.Runner

  @elixir System.find_executable("elixir")
  @shell System.find_executable("sh")

  setup_all do
    if is_nil(@elixir) do
      raise "elixir executable is required for runner tests"
    end

    :ok
  end

  test "collects output and delivers output and exit callbacks" do
    parent = self()

    script = ~S"""
    IO.binwrite(:stdio, "hello")
    IO.binwrite(:stderr, "warn")
    """

    assert {:ok, result} =
             Runner.run([@elixir, "-e", script],
               stdout: :collect,
               stderr: :collect,
               on_event: fn event -> send(parent, event) end
             )

    assert result.exit_status == 0
    assert result.stdout == "hello"
    assert result.stderr == "warn"
    assert result.duration_ms >= 0
    assert %DateTime{} = result.started_at
    assert %DateTime{} = result.finished_at

    events = collect_events([])
    assert result.argv == [@elixir, "-e", script]
    assert Enum.all?(events, fn {kind, _value} -> kind in [:stdout, :stderr, :exit] end)
    assert List.last(events) == {:exit, result}
    assert event_output(events, :stdout) == "hello"
    assert event_output(events, :stderr) == "warn"
  end

  @tag skip: is_nil(@shell)
  test "output EOF does not impose a process execution deadline" do
    assert {:ok, result} = Runner.run([@shell, "-c", "exec 1>&- 2>&-; sleep 6; exit 0"])
    assert result.exit_status == 0
    assert result.duration_ms >= 5_500
  end

  test "writes runner stdin to the external process" do
    script = ~S"""
    IO.binwrite(:stdio, IO.read(:stdio, :eof))
    """

    assert {:ok, result} = Runner.run([@elixir, "-e", script], stdin: ["hello"], stdout: :collect)
    assert result.stdout == "hello"
    assert result.stderr == ""
  end

  test "writes stdin supplied through a collectable callback" do
    input = fn sink -> Enum.into(["hello", " world"], sink) end

    assert {:ok, result} = Runner.run(["cat"], stdin: input, stdout: :collect)
    assert result.stdout == "hello world"
  end

  @tag timeout: 5_000
  test "closes stdin when no input is supplied" do
    assert {:ok, result} = Runner.run(["cat"], stdout: :collect)
    assert result.stdout == ""
  end

  test "returns typed exit errors with the result attached" do
    script = ~S"""
    IO.binwrite(:stderr, "oops")
    System.halt(12)
    """

    assert {:error, error} = Runner.run([@elixir, "-e", script], stderr: :collect)
    assert error.kind == :exit
    assert error.exit_status == 12
    assert error.result.exit_status == 12
    assert error.result.stderr == "oops"
    assert error.message =~ "status 12"

    raised =
      assert_raise Runner.Error, fn ->
        Runner.run!([@elixir, "-e", script], stderr: :collect)
      end

    assert raised.kind == :exit
    assert raised.exit_status == 12
  end

  test "returns spawn errors when the executable does not exist" do
    assert {:error, error} = Runner.run(["definitely-not-a-real-executable-ffix"])
    assert error.kind == :spawn
    assert error.exit_status == nil
    assert error.message =~ "command not found"
  end

  test "keeps only the configured stderr tail by default" do
    script = ~S"""
    IO.binwrite(:stderr, String.duplicate("a", 70_000))
    """

    assert {:ok, result} = Runner.run([@elixir, "-e", script])
    assert result.stderr == String.duplicate("a", 65_536)
    assert result.stdout == nil
  end

  test "streams both output channels regardless of retained stderr capture" do
    script = ~S"""
    IO.binwrite(:stdio, String.duplicate("out", 30_000))
    IO.binwrite(:stderr, String.duplicate("err", 30_000))
    """

    for capture <- [:collect, :discard] do
      events =
        Runner.stream([@elixir, "-e", script], stdout: :collect, stderr: capture)
        |> Enum.to_list()

      assert {:exit, result} = List.last(events)
      assert result.exit_status == 0
      assert event_output(events, :stdout) == String.duplicate("out", 30_000)
      assert event_output(events, :stderr) == String.duplicate("err", 30_000)
      assert result.stdout == event_output(events, :stdout)

      if capture == :collect do
        assert result.stderr == event_output(events, :stderr)
      else
        assert result.stderr == nil
      end
    end
  end

  test "stream returns nonzero exits while stream! raises the typed exit error" do
    script = ~S"""
    IO.binwrite(:stderr, "oops")
    System.halt(12)
    """

    events = Runner.stream([@elixir, "-e", script], stderr: :collect) |> Enum.to_list()
    assert {:stderr, _chunk} = hd(events)
    assert {:exit, result} = List.last(events)
    assert result.exit_status == 12
    assert result.stderr == "oops"
    assert event_output(events, :stderr) == "oops"

    error =
      assert_raise Runner.Error, fn ->
        Runner.stream!([@elixir, "-e", script], stderr: :collect) |> Enum.to_list()
      end

    assert error.kind == :exit
    assert error.exit_status == 12
  end

  test "callback MatchErrors during output and exit propagate unchanged" do
    for target <- [:stdout, :exit] do
      error =
        assert_raise MatchError, fn ->
          Runner.run(["sh", "-c", "printf hello"],
            on_event: fn
              {^target, _} -> raise MatchError, term: {:error, :application_bug}
              _ -> :ok
            end
          )
        end

      assert error.term == {:error, :application_bug}
    end
  end

  test "stdin producer exceptions propagate unchanged" do
    error =
      assert_raise MatchError, fn ->
        Runner.run(["cat"],
          stdin: fn _sink ->
            raise MatchError, term: {:error, :producer_bug}
          end
        )
      end

    assert error.term == {:error, :producer_bug}
  end

  @tag timeout: 5_000
  test "stdin enumerable failures propagate while output is blocked" do
    input = Stream.map([:chunk], fn _chunk -> raise "producer bug" end)

    assert_raise RuntimeError, "producer bug", fn ->
      Runner.run(["sleep", "30"], stdin: input)
    end
  end

  test "quiet commands emit only their exit result" do
    assert [{:exit, %Runner.Result{exit_status: 0, argv: ["true"]}}] =
             Runner.stream(["true"]) |> Enum.to_list()
  end

  @tag skip: is_nil(@shell) or is_nil(System.find_executable("kill")), timeout: 5_000
  test "early halt terminates the OS child" do
    os_pid =
      Runner.stream([@shell, "-c", "printf '%s\\n' \"$$\"; exec sleep 30"])
      |> Enum.reduce_while("", fn {:stdout, chunk}, buffer ->
        buffer = buffer <> chunk

        if String.ends_with?(buffer, "\n") do
          {:halt, String.trim(buffer)}
        else
          {:cont, buffer}
        end
      end)

    assert os_pid =~ ~r/\A[1-9][0-9]*\z/
    {_output, status} = System.cmd("kill", ["-0", os_pid], stderr_to_stdout: true)
    assert status != 0, "runner child survived early stream termination"
  end

  @tag timeout: 5_000
  test "early halt cleans up a blocked stdin producer" do
    parent = self()

    input = fn _sink ->
      send(parent, {:producer, self()})
      Process.sleep(:infinity)
    end

    events =
      Runner.stream(["sh", "-c", "printf ready; exec sleep 30"], stdin: input)
      |> Enum.take(1)

    assert events == [{:stdout, "ready"}]
    assert_received {:producer, producer}
    refute Process.alive?(producer)
  end

  test "early halt and consumer exceptions do not leak dependency exit errors" do
    for stream_fun <- [&Runner.stream/1, &Runner.stream!/1] do
      stream = stream_fun.(["sh", "-c", "printf hello; exit 12"])
      assert [{:stdout, "hello"}] = Enum.take(stream, 1)

      assert_raise RuntimeError, "consumer bug", fn ->
        Enum.each(stream, fn _ -> raise "consumer bug" end)
      end
    end
  end

  test "missing executable is a lazy typed stream error" do
    stream = Runner.stream(["definitely-not-a-real-executable-ffix"])
    assert [{:error, %Runner.Error{kind: :spawn}}] = Enum.to_list(stream)
    bang = Runner.stream!(["definitely-not-a-real-executable-ffix"])
    assert_raise Runner.Error, fn -> Enum.to_list(bang) end
  end

  test "serialization is lazy and fresh on each enumeration" do
    parent = self()
    source = FFix.input("in.mp4")

    command =
      FFix.command(
        FFix.output(FFix.video(source, 0), "out.mp4",
          metadata: fn _ ->
            send(parent, :serialized)
            "title=test"
          end
        )
      )

    stream = Runner.stream(command, ffmpeg: "true")
    refute_received :serialized

    for _pass <- 1..2 do
      assert [{:exit, _}] = Enum.to_list(stream)
      assert_received :serialized
      refute_received :serialized
    end
  end

  test "raw argv stays literal even when the executable is named ffmpeg" do
    directory = Path.join(System.tmp_dir!(), "ffix-runner-#{System.unique_integer([:positive])}")
    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)
    executable = Path.join(directory, "ffmpeg")
    File.write!(executable, "#!/bin/sh\nprintf '%s\\n' \"$@\"\n")
    File.chmod!(executable, 0o755)
    argv = [executable, "literal"]
    assert {:ok, result} = Runner.run(argv, progress: true, ffmpeg: "ignored", stdout: :collect)
    assert result.argv == argv
    assert result.stdout == "literal\n"
  end

  test "streams logs as raw stderr while retaining only the configured tail" do
    parent = self()
    argv = ["sh", "-c", "printf '[warning] one\\n[warning] two\\n[warning] three\\n' >&2"]
    stderr = "[warning] one\n[warning] two\n[warning] three\n"

    assert {:ok, result} =
             Runner.run(argv, stderr: {:tail, 4}, on_event: fn event -> send(parent, event) end)

    events = collect_events([])
    assert result.stderr == "ree\n"
    assert event_output(events, :stderr) == stderr
    assert Enum.all?(events, fn {kind, _value} -> kind in [:stderr, :exit] end)
    assert {:ok, collected} = Runner.run(argv, stderr: :collect)
    assert collected.stderr == stderr
  end

  test "progress grouping is independent of stderr capture limits" do
    script = ~S"""
    IO.binwrite(:stderr, "detail=" <> String.duplicate("x", 70_000) <> "\n")
    IO.binwrite(:stderr, "frame=2\nprogress=end\n")
    """

    argv = [@elixir, "-e", script]

    for capture <- [:discard, {:tail, 4}] do
      assert {:ok, result} = Runner.run(argv, progress: true, stderr: capture)
      assert result.last_progress.frame == 2
      assert result.last_progress.fields["detail"] == String.duplicate("x", 70_000)
    end
  end

  test "progress is opt-in and survives stderr discard" do
    argv = ["sh", "-c", "printf 'frame=3\\nprogress=end\\n[warning] warning' >&2"]
    assert {:ok, literal} = Runner.run(argv)
    assert literal.last_progress == nil
    events = Runner.stream(argv, progress: true, stderr: :discard) |> Enum.to_list()
    assert Enum.any?(events, &match?({:progress, %{frame: 3, status: :end}}, &1))
    assert event_output(events, :stderr) == "frame=3\nprogress=end\n[warning] warning"
    assert {:exit, result} = List.last(events)
    assert result.stderr == nil
    assert result.last_progress.frame == 3
  end

  test "groups progress at continue and end markers and resets fields between updates" do
    stderr = """
    frame=1
    speed=1.5x
    extra=a=b
    progress=continue
    [warning] duration=unknown
    frame=2
    progress=end
    frame=3
    progress=unfinished
    """

    argv = ["sh", "-c", "printf '%s' \"$1\" >&2", "runner", stderr]
    events = Runner.stream(argv, progress: true) |> Enum.to_list()

    updates =
      Enum.flat_map(events, fn
        {:progress, progress} -> [progress]
        _event -> []
      end)

    assert [first, last] = updates
    assert first.status == :continue
    assert first.frame == 1
    assert first.speed == 1.5
    assert first.fields["extra"] == "a=b"
    assert last.status == :end
    assert last.fields == %{"frame" => "2", "progress" => "end"}
    assert {:exit, result} = List.last(events)
    assert result.last_progress == last
  end

  @tag timeout: 5_000
  test "groups progress when a marker spans stderr chunks" do
    parent = self()

    input = fn sink ->
      send(parent, {:input_producer, self()})

      receive do
        :continue -> Enum.into(["continue\n"], sink)
      end
    end

    script = """
    printf 'frame=1\\nprogre' >&2
    read reply
    printf 'ss=continue\\nframe=2\\nprogress=end\\n' >&2
    """

    events =
      Runner.stream(["sh", "-c", script], stdin: input, progress: true)
      |> Stream.with_index()
      |> Enum.map(fn {event, index} ->
        if index == 0 do
          assert_receive {:input_producer, producer}, 1_000
          send(producer, :continue)
        end

        event
      end)

    updates =
      Enum.flat_map(events, fn
        {:progress, progress} -> [{progress.status, progress.frame}]
        _event -> []
      end)

    assert updates == [continue: 1, end: 2]
    assert event_output(events, :stderr) == "frame=1\nprogress=continue\nframe=2\nprogress=end\n"
  end

  test "does not emit progress without a closing marker" do
    argv = ["sh", "-c", "printf 'frame=3\\nspeed=1.5x' >&2"]
    events = Runner.stream(argv, progress: true) |> Enum.to_list()

    refute Enum.any?(events, &match?({:progress, _}, &1))
    assert {:exit, result} = List.last(events)
    assert result.last_progress == nil
  end

  test "flushes a progress marker without a final newline before the exit event" do
    argv = ["sh", "-c", "printf 'frame=3\\nprogress=end' >&2"]
    events = Runner.stream(argv, progress: true, stderr: :collect) |> Enum.to_list()

    assert [{:progress, progress}, {:exit, result}] = Enum.take(events, -2)
    assert progress.frame == 3
    assert progress.status == :end
    assert result.last_progress == progress
    assert result.stderr == "frame=3\nprogress=end"
  end

  test "closed subprocess stdin follows Exile's process exit handling" do
    input = Stream.repeatedly(fn -> String.duplicate("x", 8_192) end)
    argv = ["sh", "-c", "exec 0<&-; exit 0"]

    assert {:ok, %Runner.Result{exit_status: 0}} = Runner.run(argv, stdin: input)
    assert %Runner.Result{exit_status: 0} = Runner.run!(argv, stdin: input)

    assert [{:exit, %Runner.Result{exit_status: 0}}] =
             Runner.stream(argv, stdin: input) |> Enum.to_list()
  end

  test "invalid arguments raise instead of becoming operational errors" do
    for options <- [[stdin: :invalid], [ffmpeg: 1], [:invalid], [unknown: true]] do
      assert_raise ArgumentError, fn -> Runner.run(["true"], options) end
    end

    assert_raise ArgumentError, fn -> Runner.stream(:invalid) |> Enum.to_list() end
  end

  defp event_output(events, channel) do
    events
    |> Enum.flat_map(fn
      {^channel, chunk} -> [chunk]
      _event -> []
    end)
    |> IO.iodata_to_binary()
  end

  defp collect_events(events) do
    receive do
      event -> collect_events([event | events])
    after
      0 -> Enum.reverse(events)
    end
  end
end
