defmodule FFix.Runner.ExecutableTest do
  use ExUnit.Case, async: false

  alias FFix.Command
  alias FFix.Runner

  setup do
    previous = System.get_env("FFMPEG_BIN")

    on_exit(fn ->
      case previous do
        nil -> System.delete_env("FFMPEG_BIN")
        value -> System.put_env("FFMPEG_BIN", value)
      end
    end)

    :ok
  end

  test "Command execution resolves explicit option, environment, then ffmpeg at enumeration" do
    command =
      FFix.command("ffix-missing-input", fn source ->
        FFix.output(FFix.video(source), "-", f: "null")
      end)

    ["ffmpeg" | serialized_args] = Command.to_argv(command)
    stream = Runner.stream(command)
    System.put_env("FFMPEG_BIN", "true")
    assert [{:start, %{argv: ["true" | _]}}, {:exit, %{exit_status: 0}}] = Enum.to_list(stream)

    System.put_env("FFMPEG_BIN", "ffix-missing-executable")
    assert [{:error, %{kind: :spawn}}] = Enum.to_list(stream)
    assert {:ok, explicit} = Runner.run(command, ffmpeg: "true", progress: true)

    assert explicit.argv ==
             [
               "true",
               "-hide_banner",
               "-nostats",
               "-loglevel",
               "level+warning",
               "-progress",
               "pipe:2"
             ] ++ serialized_args

    assert Command.to_argv(command) == ["ffmpeg" | serialized_args]

    System.delete_env("FFMPEG_BIN")
    first = Runner.stream(command) |> Enum.take(1)

    case first do
      [{:start, %{argv: ["ffmpeg" | _]}}] -> :ok
      [{:error, %{kind: :spawn, result: %{argv: ["ffmpeg" | _]}}}] -> :ok
    end
  end
end
