defmodule FF.Runner do
  require Logger

  alias FF.Command

  def list_filter do
    exec(~W(ffmpeg -v quiet -filters))
  end

  def filter(name) do
    exec(~w(ffmpeg -v quiet -h filter=#{name}))
  end

  def exec(command, input \\ nil)

  def exec(%Command{} = command, input) do
    exec(Command.to_argv(command), input)
  end

  def exec(["ffmpeg" | _] = cmd, input) do
    Exile.stream!(cmd, input: input)
    |> Enum.into("")
  end

  def run(%Command{} = command) do
    Logger.info("FFmpeg command: #{Command.to_shell_string(command)}")
    Exile.stream!(Command.to_argv(command))
  end

  def run(["ffmpeg" | _] = cmd) do
    Logger.info("FFmpeg command: #{Enum.join(cmd, " ")}")
    Exile.stream!(cmd)
  end
end
