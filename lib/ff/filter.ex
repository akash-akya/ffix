defmodule FF.Filter do
  alias FF.Filter.Builder
  alias FF.Filter.Metadata

  Enum.each(Metadata.filters(), fn {name, %{inputs: inputs, outputs: outputs, desc: desc}} ->
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
        :N -> quote(do: [FF.Stream.t()])
        _ -> quote(do: FF.Stream.t())
      end)

    output_specs =
      case outputs do
        [] ->
          quote(do: FF.Terminal.t())

        [:N] ->
          quote(do: [FF.Stream.t()])

        [_single] ->
          quote(do: FF.Stream.t())

        many ->
          quote do
            {unquote_splicing(Enum.map(many, fn _ -> quote(do: FF.Stream.t()) end))}
          end
      end

    option_specs = Metadata.filter_spec(name)
    options_doc = Metadata.build_options_doc(option_specs)
    options_typespec = Metadata.build_options_typespec(option_specs)

    @doc """
    #{desc}

    ## Options

    #{options_doc}
    """
    @spec unquote(name)(unquote_splicing(input_specs), unquote(options_typespec)) :: unquote(output_specs)
    def unquote(name)(unquote_splicing(input_args), options \\ []) do
      Builder.apply_filter(
        unquote(name),
        [unquote_splicing(input_args)],
        unquote(outputs),
        options,
        unquote(Macro.escape(option_specs))
      )
    end
  end)
end
