defmodule FFix.Helpers.Generator do
  @moduledoc false

  @start "  # BEGIN GENERATED HELPERS"
  @finish "  # END GENERATED HELPERS"

  # These shared controls complement private help without presenting every
  # AVCodecContext/AVFormatContext field as a supported convenience option.
  @codec_options ~w(b g maxrate minrate bufsize threads thread_type flags flags2 profile level strict global_quality compression_level skip_frame skip_idct skip_loop_filter lowres err_detect)
  @format_options ~w(fflags avioflags probesize analyzeduration max_delay flush_packets avoid_negative_ts)

  @spec update(String.t(), map(), atom()) :: String.t()
  def update(source, snapshot, kind) do
    entries = Enum.filter(snapshot.components, &(&1.kind == kind))
    generated = Enum.map_join(entries, "\n", &registration(&1, snapshot))
    [prefix, rest] = String.split(source, @start, parts: 2)
    [_previous, suffix] = String.split(rest, @finish, parts: 2)
    result = prefix <> @start <> "\n" <> generated <> @finish <> suffix
    result |> Code.format_string!() |> IO.iodata_to_binary() |> Kernel.<>("\n")
  end

  defp registration(entry, snapshot) do
    options = option_entries(entry, snapshot.shared)
    schema = schema(options)

    entry.names
    |> Enum.filter(&String.match?(&1, ~r/^[a-z][a-z0-9_]*$/))
    |> Enum.map_join("\n", fn name ->
      if name in ~w(new named auto build_input build_output check_media!) do
        raise ArgumentError, "helper name conflicts with an existing function: #{name}"
      end

      helper(entry, name, schema, options, snapshot.version.version)
    end)
  end

  defp option_entries(entry, shared) do
    {owner, names, direction} =
      case entry.kind do
        :encoder -> {"AVCodecContext", @codec_options, "E"}
        :decoder -> {"AVCodecContext", @codec_options, "D"}
        :muxer -> {"AVFormatContext", @format_options, "E"}
        :demuxer -> {"AVFormatContext", @format_options, "D"}
      end

    shared_options =
      shared
      |> Enum.filter(&(&1.name == owner))
      |> Enum.flat_map(& &1.options)
      |> Enum.filter(fn option ->
        option.name in names and String.contains?(option.flags, direction) and
          applicable_media?(option.flags, entry.media_type)
      end)
      |> Enum.map(&{owner, &1})

    private_options =
      Enum.flat_map(entry.option_sections, fn section ->
        Enum.map(section.options, &{section.name, &1})
      end)

    (private_options ++ shared_options)
    |> Enum.reject(fn {_owner, option} -> String.contains?(option.flags, "R") end)
  end

  defp applicable_media?(flags, media) do
    flag =
      case media do
        :video -> "V"
        :audio -> "A"
        nil -> nil
      end

    media_specific? = String.contains?(flags, ["V", "A", "S"])
    flag == nil or not media_specific? or String.contains?(flags, flag)
  end

  defp schema(options) do
    options
    |> Enum.group_by(fn {_owner, option} -> option.name end)
    |> Map.new(fn {name, entries} ->
      variants =
        Enum.map(entries, fn {_owner, option} ->
          %{type: option.type, constants: Enum.map(option.constants, & &1.name)}
        end)

      {name, Enum.uniq(variants)}
    end)
  end

  defp helper(entry, name, schema, options, version) do
    schema_name = "#{name}_schema"
    type_name = "#{name}_option"
    declarations = option_types(schema, entry.kind) ++ special_types(entry.kind)
    option_type = Enum.join(declarations, " | ")
    doc = documentation(entry, name, options, version)

    header = """
      @#{schema_name} #{inspect(schema, limit: :infinity, printable_limit: :infinity)}
      @type #{type_name} :: #{option_type}
      @doc #{doc_literal(doc)}
    """

    body =
      case entry.kind do
        :encoder ->
          """
          @spec #{name}(Command.source(), [#{type_name}()]) :: Mapping.t()
          def #{name}(source, options \\\\ []) do
            options = Options.normalize!(options, @#{schema_name}, #{inspect(name <> " encoder")})
            named(source, #{inspect(name)}, options)
          end
          """

        :decoder ->
          selector = inspect({entry.media_type, 0})

          """
          @spec #{name}(Input.t(), [#{type_name}()]) :: Input.t()
          def #{name}(input, options \\\\ []), do: #{name}(input, #{selector}, options)

          @doc "Configures an explicitly indexed input stream. See `#{name}/2` for options."
          @spec #{name}(Input.t(), Input.decoder_selector(), [#{type_name}()]) :: Input.t()
          def #{name}(input, selector, options) do
            check_media!(selector, #{inspect(entry.media_type)})
            options = Options.normalize!(options, @#{schema_name}, #{inspect(name <> " decoder")})
            named(input, selector, #{inspect(name)}, options)
          end
          """

        :muxer ->
          """
          @spec #{name}(Output.target(), [#{type_name}()]) :: Output.t()
          def #{name}(target, options) do
            build_output(target, #{inspect(name)}, options, @#{schema_name})
          end
          """

        :demuxer ->
          """
          @spec #{name}(Input.source(), [#{type_name}()]) :: Input.t()
          def #{name}(source, options \\\\ []) do
            build_input(source, #{inspect(name)}, options, @#{schema_name})
          end
          """
      end

    header <> body <> "\n"
  end

  defp option_types(schema, kind) do
    schema
    |> Enum.sort_by(fn {name, _variants} -> name end)
    |> Enum.map(fn {name, variants} ->
      types = variants |> Enum.flat_map(&value_types/1) |> Enum.uniq()
      value_type = Enum.join(types, " | ")

      if kind in [:encoder, :muxer] do
        "{:#{inspect(name)}, #{value_type} | Command.option_callback()}"
      else
        "{:#{inspect(name)}, #{value_type}}"
      end
    end)
  end

  defp value_types(%{type: type, constants: constants}) do
    symbols = Enum.map(constants, &(":" <> inspect(&1)))

    types =
      case type do
        type when type in [:int, :int64, :uint64, :unsigned] ->
          ["integer()", "String.t()"]

        type when type in [:float, :double, :duration, :rational, :video_rate] ->
          ["number()", "String.t()"]

        :boolean ->
          ["boolean()", ":auto", "String.t()"]

        :flags ->
          ["integer()", "String.t()", "[#{Enum.join(["String.t()" | symbols], " | ")}]"]

        {:unknown, _name} ->
          ["String.t()", "number()", "boolean()", "atom()"]

        type
        when type in [
               :string,
               :binary,
               :image_size,
               :pix_fmt,
               :sample_fmt,
               :channel_layout,
               :dictionary,
               :color
             ] ->
          ["String.t()", "atom()"]

        _other ->
          ["String.t()"]
      end

    types ++ symbols
  end

  defp special_types(kind) do
    common =
      if kind in [:encoder, :muxer] do
        ["{:raw, [Command.output_av_option()]}"]
      else
        ["{:raw, [Command.av_option()]}"]
      end

    case kind do
      :muxer ->
        common ++
          [
            "{:video, Command.binding() | [Command.binding()]}",
            "{:audio, Command.binding() | [Command.binding()]}",
            "{:sources, [Command.binding()]}",
            "{:output_options, [Command.option()]}"
          ]

      :demuxer ->
        common ++ ["{:input_options, [Command.option()]}"]

      _codec ->
        common
    end
  end

  defp doc_literal(doc) do
    lines =
      doc
      |> String.trim_trailing("\n")
      |> String.split("\n")
      |> Enum.map(fn line ->
        quoted = inspect(String.trim_trailing(line), limit: :infinity, printable_limit: :infinity)
        binary_part(quoted, 1, byte_size(quoted) - 2)
      end)

    "\"\"\"\n" <> Enum.join(lines, "\n") <> "\n\"\"\""
  end

  defp documentation(entry, name, options, version) do
    role =
      case entry.kind do
        :encoder ->
          "Maps one source to an independent encoded output stream."

        :decoder ->
          "Configures the first #{entry.media_type} stream; use the three-argument form for another index."

        :muxer ->
          "Builds an output declaration. Pass video/audio or ordered sources; raw CLI controls go in output_options."

        :demuxer ->
          "Builds an input declaration. Raw CLI controls go in input_options."
      end

    rows =
      Enum.map_join(options, "\n", fn {owner, option} ->
        constants = Enum.map_join(option.constants, ", ", & &1.name)

        suffix =
          case constants do
            "" -> ""
            names -> " Reported constants: #{names}."
          end

        "  * `#{option.name}` (#{owner}, #{inspect(option.type)}): #{option.help}" <> suffix
      end)

    properties =
      Enum.map_join(entry.properties, "\n", fn {label, value} ->
        "  * #{label}: #{value}"
      end)

    """
    #{name}: #{entry.description}

    #{role}

    #{properties}

    Metadata baseline: FFmpeg #{version}. Option defaults/ranges below are reported
    metadata, not emitted defaults or a complete validator. Strings remain an
    escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

    ## Options

    #{rows}
    """
  end
end
