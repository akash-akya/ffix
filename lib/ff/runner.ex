defmodule FF.Runner do
  require Logger

  def list_filter do
    exec(~W(ffmpeg -v quiet -filters))
  end

  def filter(name) do
    exec(~w(ffmpeg -v quiet -h filter=#{name}))
  end

  def exec(["ffmpeg" | _] = cmd, input \\ nil) do
    Exile.stream!(cmd, input: input)
    |> Enum.into("")
  end

  def run(["ffmpeg" | _] = cmd) do
    Logger.info("FFmpeg command: #{Enum.join(cmd, " ")}")
    Exile.stream!(cmd)
  end
end
