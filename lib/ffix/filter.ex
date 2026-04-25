defmodule FFix.Filter do
  @moduledoc """
  Generated helpers for ffmpeg filters.

  Each function mirrors one filter reported by the local `ffmpeg` executable at
  compile time. Function arguments are `FFix.Stream` values; the final argument is
  a keyword list of ffmpeg filter options.

      video
      |> scale(w: 1280, h: -1)
      |> fps(fps: 30)

  Most filters return a single `FFix.Stream`. Multi-output filters return a tuple
  or list:

      [left, right] = split(video, outputs: 2)
      stacked = hstack([left, hflip(right)])

  Some ffmpeg filters have dynamic output shapes. Use `FFix.shape/2` when the
  generated metadata cannot infer the shape you need:

      [audio, video] =
        audio_in
        |> ebur128(video: true)
        |> FFix.shape([:audio, :video])

  Option keys are ffmpeg option names. Values are normalized where metadata is
  available, but raw strings remain an escape hatch for ffmpeg-specific syntax.
  """

  alias FFix.Filter.Builder
  alias FFix.Filter.Metadata

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
        :N -> quote(do: [FFix.Stream.t()])
        _ -> quote(do: FFix.Stream.t())
      end)

    output_specs =
      case outputs do
        [] ->
          quote(do: FFix.Terminal.t())

        [:N] ->
          quote(do: [FFix.Stream.t()])

        [_single] ->
          quote(do: FFix.Stream.t())

        many ->
          quote do
            {unquote_splicing(Enum.map(many, fn _ -> quote(do: FFix.Stream.t()) end))}
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
    @spec unquote(name)(unquote_splicing(input_specs), unquote(options_typespec)) ::
            unquote(output_specs)
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
