defmodule FFix.Filter.Helpers do
  @moduledoc false

  alias FFix.Filter.Schema

  @spec definitions(map()) :: [Macro.t()]
  def definitions(metadata) do
    normalized = Schema.normalize!(Map.fetch!(metadata, :filters))

    normalized.filters
    |> Enum.sort_by(fn {name, _filter} -> name end)
    |> Enum.map(fn {name, filter} ->
      if name == :filter do
        raise ArgumentError, "filter helper name conflicts with the generic filter operation"
      end

      helper(name, filter, Map.fetch!(normalized.specs, name), metadata.version.version)
    end)
  end

  defp helper(name, filter, option_specs, version) do
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

    doc = """
    #{name}: #{filter.desc}

    Metadata baseline: FFmpeg #{version}.

    ## Options

    #{build_options_doc(option_specs)}
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
        quote(do: FFix.Graph.StreamRef.t() | [FFix.Graph.StreamRef.t()])

      [_single] ->
        quote(do: FFix.Graph.StreamRef.t())

      many ->
        streams = Enum.map(many, fn _pad -> quote(do: FFix.Graph.StreamRef.t()) end)
        quote(do: {unquote_splicing(streams)})
    end
  end

  defp filter_group(inputs, outputs) do
    cond do
      inputs == [] ->
        "Source filters"

      outputs == [] ->
        "Sink filters"

      :N in inputs or :N in outputs ->
        "Multi-stream filters"

      :A in inputs or :A in outputs ->
        if :V in inputs or :V in outputs do
          "Audio/video filters"
        else
          "Audio filters"
        end

      :V in inputs or :V in outputs ->
        "Video filters"

      true ->
        "Other filters"
    end
  end

  @spec build_options_doc(map()) :: String.t()
  def build_options_doc(options) do
    options
    |> Enum.sort_by(fn {name, _config} -> name end)
    |> Enum.map_join("\n", fn {name, config} ->
      owner =
        case config do
          %{owner: owner} -> owner
          %{implicit: :timeline} -> "implicit timeline"
        end

      constants =
        config
        |> Map.get(:sub, [])
        |> Enum.map_join("\n", fn constant ->
          number =
            case constant.num do
              "" -> ""
              value -> " (#{value})"
            end

          "    - #{constant.enum}#{number} - #{constant.desc}"
        end)

      row = "  * `#{name}` (#{owner}, #{inspect(config.type)}): #{config.desc}"

      case constants do
        "" -> row
        values -> row <> "\n" <> values
      end
    end)
  end

  @spec build_options_typespec(map()) :: Macro.t()
  def build_options_typespec(options) do
    # Optionless filters already accept arbitrary keywords in the builder.
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
    scalar = quote(do: String.t() | atom() | number() | FFix.Graph.Expr.t())

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
