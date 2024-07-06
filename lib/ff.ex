defmodule FF do
  def filters do
    list = FF.Runner.list_filter()

    list
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
end
