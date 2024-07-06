defmodule FF.Filter do
  alias FF.Filter.Builder
  alias FF.Filter.Builder.Pad

  @ffmpeg System.find_executable("ffmpeg")
  @quiet ["-v", "quiet"]

  System.cmd(@ffmpeg, @quiet ++ ["-filters"])
  |> then(fn
    {output, 0} ->
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
  end)
  |> Enum.map(fn {name, %{inputs: inputs, outputs: outputs, desc: desc}} ->
    inputs = Enum.reject(inputs, &(&1 == :|))
    outputs = Enum.reject(outputs, &(&1 == :|))

    input_args =
      inputs
      |> Enum.with_index()
      |> Enum.map(fn {type, idx} ->
        case type do
          :V -> "video_#{idx}"
          :A -> "audio_#{idx}"
          :N -> "streams"
        end
        |> String.to_atom()
        |> Macro.var(__MODULE__)
      end)

    input_specs =
      Enum.map(inputs, fn
        :N -> quote(do: [Pad.t()])
        _input -> quote(do: Pad.t())
      end)

    output_specs =
      case outputs do
        [] ->
          quote(do: nil)

        [:N] ->
          quote(do: [Pad.t()])

        [term] when term in [:A, :V] ->
          quote(do: Pad.t())

        _ ->
          quote do
            # if there are more than one output, return tuple
            {unquote_splicing(
               Enum.map(outputs, fn _out ->
                 quote(do: Pad.t())
               end)
             )}
          end
      end

    @doc """
    #{desc}
    """
    @spec unquote(name)(unquote_splicing(input_specs)) :: unquote(output_specs)
    def unquote(name)(unquote_splicing(input_args)) do
      Builder.operation(unquote(name), unquote(input_args), unquote(outputs))
    end
  end)
end
