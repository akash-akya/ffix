defmodule FFix.DiscoveryTest do
  use ExUnit.Case, async: false

  alias FFix.Discovery
  alias FFix.Discovery.Error

  @moduletag :capture_log
  @shell System.find_executable("sh")

  setup do
    directory =
      Path.join(System.tmp_dir!(), "ffix discovery #{System.unique_integer([:positive])}")

    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)
    {:ok, directory: directory}
  end

  test "passes literal arguments, honors FFMPEG_BIN, and records the executable", context do
    argv_file = Path.join(context.directory, "argv")

    executable =
      executable(context, """
      [ "$LC_ALL" = C ] || exit 1
      printf '%s\\n' "$@" >> '#{argv_file}'
      case "$4" in
        -encoders) printf 'Encoders:\\n ------\\n V..... codec;name Example\\n';;
        -h) printf 'Encoder codec;name [Example]:\\n';;
        -version) printf 'ffmpeg version test-build Copyright\\n';;
      esac
      """)

    previous = System.get_env("FFMPEG_BIN")
    System.put_env("FFMPEG_BIN", executable)

    on_exit(fn ->
      if previous do
        System.put_env("FFMPEG_BIN", previous)
      else
        System.delete_env("FFMPEG_BIN")
      end
    end)

    assert {:ok, %{names: ["codec;name"], option_sections: []}} =
             Discovery.help(:encoder, "codec;name")

    assert {:ok, %{version: "test-build", executable: ^executable}} = Discovery.version()
    assert File.read!(argv_file) =~ "-h\nencoder=codec;name\n"
  end

  test "registered protocols without help differ from absent names", context do
    executable =
      executable(context, """
      case "$4" in
        -protocols) printf 'Supported file protocols:\\nOutput:\\n  md5\\n';;
        -h) printf "Unknown protocol 'md5'.\\n";;
      esac
      """)

    assert {:error, %Error{reason: :help_unavailable}} =
             Discovery.help(:protocol, "md5", ffmpeg: executable)

    assert {:error, %Error{reason: :not_found}} =
             Discovery.help(:protocol, "missing", ffmpeg: executable)
  end

  test "zero exit status does not make malformed or mismatched metadata successful", context do
    executable =
      executable(context, """
      case "$4" in
        -encoders) printf 'Encoders:\\n ------\\n V..... expected Example\\n';;
        -h) printf 'Encoder different [Example]:\\n';;
        *) printf 'Unknown help option.\\n';;
      esac
      """)

    assert {:error, %Error{reason: :invalid_output}} =
             Discovery.help(:encoder, "expected", ffmpeg: executable)

    assert {:error, %Error{reason: :invalid_output, output: output}} =
             Discovery.list(:muxer, ffmpeg: executable)

    assert output == "Unknown help option.\n"
  end

  test "command failures and output limits retain bounded diagnostic output", context do
    executable = executable(context, "printf 'failed' >&2; exit 7")

    assert {:error, %Error{reason: :command_failed, exit_status: {:status, 7}, output: "failed"}} =
             Discovery.version(ffmpeg: executable)

    executable = executable(context, "while :; do printf '0123456789'; done")

    assert {:error, %Error{reason: :output_limit, output: output}} =
             Discovery.version(ffmpeg: executable, max_output: 16)

    assert byte_size(output) == 16

    assert {:error, %Error{reason: :executable_not_found}} =
             Discovery.version(ffmpeg: Path.join(context.directory, "absent"))
  end

  test "timeout terminates the OS child rather than only abandoning the caller", context do
    pid_file = Path.join(context.directory, "pid")
    executable = executable(context, "echo $$ > '#{pid_file}'\nexec sleep 30\n")

    assert {:error, %Error{reason: :timeout}} =
             Discovery.version(ffmpeg: executable, timeout: 1_000)

    os_pid = pid_file |> File.read!() |> String.trim()

    assert wait_for_exit(os_pid, 100), "FFmpeg discovery child survived its timeout"
  end

  defp wait_for_exit(_os_pid, 0), do: false

  defp wait_for_exit(os_pid, attempts) do
    case System.cmd("kill", ["-0", os_pid], stderr_to_stdout: true) do
      {_output, 0} ->
        Process.sleep(20)
        wait_for_exit(os_pid, attempts - 1)

      _ ->
        true
    end
  end

  defp executable(context, body) do
    path = Path.join(context.directory, "ffmpeg #{System.unique_integer([:positive])}")
    File.write!(path, "#!#{@shell}\n" <> body)
    File.chmod!(path, 0o700)
    path
  end
end
