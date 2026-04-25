defmodule FFix.Filter.Help do
  @moduledoc false

  @ffmpeg_bin System.get_env("FFMPEG_BIN")
  @ffmpeg if @ffmpeg_bin in [nil, ""], do: System.find_executable("ffmpeg"), else: @ffmpeg_bin
  @quiet ["-v", "quiet"]

  def filter(name) do
    {output, 0} = exec(["-h", "filter=#{name}"])
    lines = String.split(output, "\n", trim: true)

    first_filter_option_section(lines) ++
      option_section(lines, "framesync AVOptions:")
  end

  def filters do
    {output, 0} = exec(["-filters"])

    output
    |> String.split("\n", trim: true)
    |> Enum.drop_while(fn line -> !String.contains?(line, "->") end)
    |> Enum.map(&FFix.Parsers.FilterList.parse/1)
    |> Enum.sort()
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

  defp first_filter_option_section(lines) do
    Enum.find_index(lines, fn line ->
      String.contains?(line, "AVOptions:") and line != "framesync AVOptions:" and
        line != "SWScaler AVOptions:"
    end)
    |> option_section_at(lines)
  end

  defp option_section(lines, header) do
    lines
    |> Enum.find_index(&(&1 == header))
    |> option_section_at(lines)
  end

  defp option_section_at(index, lines) do
    case index do
      nil ->
        []

      index ->
        lines
        |> Enum.drop(index + 1)
        |> Enum.take_while(&String.starts_with?(&1, " "))
        |> Enum.filter(&(String.trim(&1) != ""))
    end
  end

  def exec(args) do
    ffmpeg = ffmpeg!()

    case System.cmd(ffmpeg, @quiet ++ args) do
      {output, 0} ->
        {output, 0}

      {output, status} ->
        raise """
        ffmpeg metadata command failed with status #{status}.

        FFix needs ffmpeg at compile time to generate filter helpers.
        Command: #{Enum.join([ffmpeg | @quiet ++ args], " ")}
        Output:
        #{output}
        """
    end
  rescue
    error in ErlangError ->
      raise """
      failed to run ffmpeg for compile-time filter metadata.

      FFix needs ffmpeg at compile time to generate filter helpers.
      Install ffmpeg or set FFMPEG_BIN to the ffmpeg executable path.

      Error: #{Exception.message(error)}
      """
  end

  defp ffmpeg! do
    if @ffmpeg do
      @ffmpeg
    else
      raise """
      ffmpeg executable was not found.

      FFix needs ffmpeg at compile time to generate filter helpers.
      Install ffmpeg or set FFMPEG_BIN to the ffmpeg executable path.
      """
    end
  end
end
