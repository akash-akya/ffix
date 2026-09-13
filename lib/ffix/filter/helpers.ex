defmodule FFix.Filter.Helpers do
  @moduledoc false

  alias FFix.Filter.Schema

  @spec definitions(map()) :: [Macro.t()]
  def definitions(metadata) do
    normalized = Schema.normalize!(Map.fetch!(metadata, :filters))
    definitions(normalized.filters, normalized.specs)
  end

  @spec definitions(map(), map()) :: [Macro.t()]
  def definitions(filters, specs) do
    filters
    |> Enum.sort_by(fn {name, _filter} -> name end)
    |> Enum.map(fn {name, filter} ->
      if name == :filter do
        raise ArgumentError, "filter helper name conflicts with the generic filter operation"
      end

      helper(name, filter, Map.fetch!(specs, name))
    end)
  end

  defp helper(name, filter, option_specs) do
    inputs = Enum.reject(filter.inputs, &(&1 == :|))
    outputs = Enum.reject(filter.outputs, &(&1 == :|))
    group = filter_group(inputs, outputs)

    input_args =
      inputs
      |> Enum.with_index()
      |> Enum.map(fn {type, index} ->
        argument =
          case type do
            :V -> "video_#{index}"
            :A -> "audio_#{index}"
            :N -> "streams"
          end

        Macro.var(String.to_atom(argument), __MODULE__)
      end)

    input_specs =
      Enum.map(inputs, fn
        :N -> quote(do: [FFix.Graph.StreamRef.t()])
        _fixed -> quote(do: FFix.Graph.StreamRef.t())
      end)

    output_spec = output_typespec(outputs)
    options_typespec = build_options_typespec(option_specs)

    example = filter_example(name)

    example =
      if example do
        "## Example\n\n    #{example}\n"
      else
        ""
      end

    doc = """
    #{filter.desc}

    #{example}
    ## Options

    #{build_options_doc(option_specs)}

    See `FFix.Filter` for pipelines, expressions, and output handling.
    """

    quote do
      @doc group: unquote(group)
      @doc unquote(doc)
      @spec unquote(name)(unquote_splicing(input_specs), unquote(options_typespec)) ::
              unquote(output_spec)
      def unquote(name)(unquote_splicing(input_args), options \\ []) do
        FFix.Graph.Builder.apply_filter(
          unquote(name),
          [unquote_splicing(input_args)],
          unquote(inputs),
          unquote(outputs),
          options,
          unquote(Macro.escape(option_specs))
        )
      end
    end
  end

  defp output_typespec(outputs) do
    case outputs do
      [] ->
        quote(do: FFix.Graph.Terminal.t())

      [:N] ->
        quote(do: FFix.Graph.StreamRef.t() | [FFix.Graph.StreamRef.t()] | FFix.Graph.Terminal.t())

      [_single] ->
        quote(do: FFix.Graph.StreamRef.t())

      _many ->
        quote(do: [FFix.Graph.StreamRef.t()])
    end
  end

  defp filter_group(inputs, outputs) do
    media = inputs ++ outputs

    cond do
      inputs == [] or outputs == [] -> "Sources and sinks"
      :V in media and :A not in media -> "Video"
      :A in media and :V not in media -> "Audio"
      true -> "Other filters"
    end
  end

  defp filter_example(name) do
    examples = %{
      scale: ~s|FFix.Filter.scale(video, w: 1280, h: -2)|,
      crop: ~s|FFix.Filter.crop(video, w: 720, h: 720)|,
      overlay: ~s|FFix.Filter.overlay(background, logo, x: 20, y: 20)|,
      split: ~s|[main, preview] = FFix.Filter.split(video, outputs: 2)|,
      volume: ~s|FFix.Filter.volume(audio, volume: 0.5)|,
      amix: ~s|FFix.Filter.amix([voice, music], inputs: 2, duration: :shortest)|,
      sine: ~s|FFix.Filter.sine(frequency: 440, duration: 2)|,
      testsrc2: ~s|FFix.Filter.testsrc2(size: "640x360", rate: 30, duration: 2)|,
      ebur128: ~s|[meter, audio] = FFix.Filter.ebur128(audio, video: true)|
    }

    Map.get(examples, name)
  end

  @spec build_options_doc(map()) :: String.t()
  def build_options_doc(options) do
    options
    |> Enum.sort_by(fn {name, _config} -> name end)
    |> Enum.map_join("\n", fn {name, config} ->
      constants =
        config
        |> Map.get(:sub, [])
        |> Enum.map_join("\n", fn constant ->
          number =
            case constant.num do
              "" -> ""
              value -> " (#{value})"
            end

          "    - `#{constant.enum}`#{number}" <>
            FFix.Helpers.description_suffix(constant.desc, " — ")
        end)

      row =
        "- `#{name}` (#{FFix.Helpers.option_type(config.type)})" <>
          FFix.Helpers.description_suffix(config.desc, ": ")

      case constants do
        "" -> row
        values -> row <> "\n" <> values
      end
    end)
  end

  @spec build_options_typespec(map()) :: Macro.t()
  def build_options_typespec(options) do
    case map_size(options) do
      0 ->
        quote(do: keyword())

      _count ->
        entries =
          options
          |> Map.delete(:pos)
          |> Enum.sort_by(fn {name, _config} -> name end)
          |> Enum.map(fn {name, config} ->
            quote(do: {unquote(name), unquote(value_typespec(config.type))})
          end)

        positional = quote(do: {:pos, unquote(value_typespec(:string))})
        quote(do: [unquote_splicing(entries ++ [positional])])
    end
  end

  defp value_typespec(type) do
    # Filter Value normalization deliberately accepts scalar conveniences and
    # arbitrary symbols, unlike command-option validation against constants.
    scalar = quote(do: String.t() | atom() | number())

    case type do
      {:array, inner} ->
        element = value_typespec(inner)
        quote(do: unquote(element) | [unquote(element)])

      :flags ->
        quote(do: unquote(scalar) | [unquote(scalar)])

      _scalar ->
        scalar
    end
  end
end
