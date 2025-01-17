defmodule FF.Filter.Help do
  @moduledoc false

  @ffmpeg System.find_executable("ffmpeg")
  @quiet ["-v", "quiet"]

  def filter(name) do
    {output, 0} = exec(["-h", "filter=#{name}"])
    lines = String.split(output, "\n", trim: true)
    index = Enum.find_index(lines, &String.contains?(&1, "AVOptions:"))

    lines
    |> Enum.drop(index + 1)
    |> Enum.take_while(&String.starts_with?(&1, " "))
    |> Enum.filter(&(String.trim(&1) != ""))
  end

  def filters do
    {output, 0} = exec(["-filters"])

    output
    |> String.split("\n", trim: true)
    |> Enum.drop_while(fn line -> !String.contains?(line, "->") end)
    |> Enum.map(&FF.Parsers.FilterList.parse/1)
    |> Map.new(fn [flags, name, {inputs, outputs}, desc] ->
      {
        String.to_atom(name),
        %{
          flags: flags,
          inputs: inputs,
          outputs: outputs,
          desc: desc
        }
      }
    end)
  end

  def exec(args) do
    System.cmd(@ffmpeg, @quiet ++ args)
  end
end
