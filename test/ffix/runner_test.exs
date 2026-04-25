defmodule FFix.RunnerTest do
  use ExUnit.Case, async: true

  alias FFix.Runner

  @elixir System.find_executable("elixir")

  setup_all do
    if is_nil(@elixir) do
      raise "elixir executable is required for runner tests"
    end

    :ok
  end

  test "runs a command and collects stdout and stderr when requested" do
    script = ~S"""
    IO.binwrite(:stdio, "hello")
    IO.binwrite(:stderr, "warn")
    """

    assert {:ok, result} = Runner.run([@elixir, "-e", script], stdout: :collect, stderr: :collect)
    assert result.exit_status == 0
    assert result.stdout == "hello"
    assert result.stderr == "warn"
    assert result.duration_ms >= 0
    assert %DateTime{} = result.started_at
    assert %DateTime{} = result.finished_at
  end

  test "writes runner stdin to the external process" do
    script = ~S"""
    IO.binwrite(:stdio, IO.read(:stdio, :eof))
    """

    assert {:ok, result} = Runner.run([@elixir, "-e", script], stdin: ["hello"], stdout: :collect)
    assert result.stdout == "hello"
    assert result.stderr == ""
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

    assert_raise FFix.Runner.Error, fn ->
      Runner.run!([@elixir, "-e", script], stderr: :collect)
    end
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
    assert byte_size(result.stderr) == 65_536
    assert result.stderr == String.duplicate("a", 65_536)
    assert result.stdout == nil
  end

  test "emits start, stream, and exit events" do
    parent = self()

    script = ~S"""
    IO.binwrite(:stdio, "hello")
    """

    assert {:ok, result} =
             Runner.run([@elixir, "-e", script],
               stdout: :collect,
               on_event: fn event -> send(parent, event) end
             )

    assert_receive {:start, %{argv: [@elixir, "-e", ^script], shell: shell}}
    assert shell =~ @elixir
    assert_receive {:stdout, "hello"}
    assert_receive {:exit, ^result}
  end

  test "streams command events and includes the final result" do
    script = ~S"""
    IO.binwrite(:stdio, "hello")
    IO.binwrite(:stderr, "warn")
    """

    events =
      Runner.stream([@elixir, "-e", script], stdout: :collect, stderr: :collect)
      |> Enum.to_list()

    assert [{:start, _}, {:stdout, "hello"}, {:stderr, "warn"}, {:exit, result}] = events
    assert result.exit_status == 0
    assert result.stdout == "hello"
    assert result.stderr == "warn"
  end

  test "stream returns the final result for non-zero exits" do
    script = ~S"""
    IO.binwrite(:stderr, "oops")
    System.halt(12)
    """

    assert [{:start, _}, {:stderr, "oops"}, {:exit, result}] =
             Runner.stream([@elixir, "-e", script], stderr: :collect) |> Enum.to_list()

    assert result.exit_status == 12
    assert result.stderr == "oops"
  end

  test "stream! raises on non-zero exits" do
    script = ~S"""
    IO.binwrite(:stderr, "oops")
    System.halt(12)
    """

    assert_raise FFix.Runner.Error, fn ->
      Runner.stream!([@elixir, "-e", script], stderr: :collect) |> Enum.to_list()
    end
  end

  test "stderr discard suppresses stderr-derived events" do
    parent = self()

    script = ~S"""
    IO.binwrite(:stdio, "hello")
    IO.binwrite(:stderr, "warn")
    """

    events =
      Runner.stream([@elixir, "-e", script], stdout: :collect, stderr: :discard)
      |> Enum.to_list()

    assert [{:start, _}, {:stdout, "hello"}, {:exit, result}] = events
    assert result.stderr == nil

    assert {:ok, _result} =
             Runner.run([@elixir, "-e", script],
               stdout: :collect,
               stderr: :discard,
               on_event: fn event -> send(parent, event) end
             )

    received_events = collect_events([])

    assert Enum.any?(received_events, &match?({:stdout, "hello"}, &1))
    refute Enum.any?(received_events, &match?({:stderr, _}, &1))
    refute Enum.any?(received_events, &match?({:log, _}, &1))
    refute Enum.any?(received_events, &match?({:progress, _}, &1))
  end

  defp collect_events(events) do
    receive do
      event -> collect_events([event | events])
    after
      0 -> Enum.reverse(events)
    end
  end
end
