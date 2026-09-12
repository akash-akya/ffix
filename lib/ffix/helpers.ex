defmodule FFix.Helpers do
  @moduledoc false

  @metadata_path Path.expand("../../priv/ffmpeg/metadata.exs", __DIR__)

  # Shared controls supplement private options without exposing every AVOption.
  @codec_options ~w(b g maxrate minrate bufsize threads thread_type flags flags2 profile level strict global_quality compression_level skip_frame skip_idct skip_loop_filter lowres err_detect)
  @format_options ~w(fflags avioflags probesize analyzeduration max_delay flush_packets avoid_negative_ts)

  defmacro define(kind) when kind in [:encoder, :decoder, :muxer, :demuxer, :filter] do
    {metadata, []} = Code.eval_file(@metadata_path)
    definitions = definitions(metadata, kind)

    quote do
      @external_resource unquote(@metadata_path)
      unquote_splicing(definitions)
    end
  end

  @spec definitions(map(), atom()) :: [Macro.t()]
  def definitions(metadata, kind) do
    case kind do
      :filter -> FFix.Filter.Helpers.definitions(metadata)
      _component -> component_definitions(metadata, kind)
    end
  end

  defp component_definitions(metadata, kind) do
    metadata.components
    |> Enum.filter(&(&1.kind == kind))
    |> Enum.flat_map(fn entry ->
      options = option_entries(entry, metadata.shared)
      schema = schema(options)

      entry.names
      |> Enum.filter(&String.match?(&1, ~r/^[a-z][a-z0-9_]*$/))
      |> Enum.map(fn name ->
        if name in ~w(new encode decode mux demux auto build_input build_output check_media!) do
          raise ArgumentError, "helper name conflicts with an existing function: #{name}"
        end

        helper(entry, name, schema, options)
      end)
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

  defp helper(entry, name, schema, options) do
    function_name = String.to_atom(name)
    type_name = {String.to_atom("#{name}_option"), [], []}
    option_type = union(option_types(schema, entry.kind) ++ special_types(entry.kind))
    doc = documentation(entry, name, options)
    schema = Macro.escape(schema)

    body =
      case entry.kind do
        :encoder ->
          quote do
            @spec unquote(function_name)(FFix.Command.source(), [unquote(type_name)]) ::
                    FFix.Command.Mapping.t()
            def unquote(function_name)(source, options \\ []) do
              FFix.Encoder.validate_source_media!(source, unquote(entry.media_type))

              options =
                FFix.Options.normalize!(options, unquote(schema), unquote(name <> " encoder"))

              encode(source, unquote(name), options)
            end
          end

        :decoder ->
          quote do
            @spec unquote(function_name)(
                    FFix.Command.Input.t(),
                    FFix.Command.Input.decoder_selector(),
                    [unquote(type_name)]
                  ) :: FFix.Command.Input.t()
            def unquote(function_name)(input, selector, options \\ []) do
              check_media!(selector, unquote(entry.media_type))

              options =
                FFix.Options.normalize!(options, unquote(schema), unquote(name <> " decoder"))

              decode(input, unquote(name), selector, options)
            end
          end

        :muxer ->
          quote do
            @spec unquote(function_name)(
                    FFix.Command.binding() | [FFix.Command.binding()],
                    FFix.Command.Output.target(),
                    [unquote(type_name)]
                  ) :: FFix.Command.Output.t()
            def unquote(function_name)(sources, target, options \\ []) do
              build_output(sources, unquote(name), target, options, unquote(schema))
            end
          end

        :demuxer ->
          quote do
            @spec unquote(function_name)(FFix.Command.Input.source(), [unquote(type_name)]) ::
                    FFix.Command.Input.t()
            def unquote(function_name)(source, options \\ []) do
              build_input(source, unquote(name), options, unquote(schema))
            end
          end
      end

    quote do
      @type unquote(type_name) :: unquote(option_type)
      @doc unquote(doc)
      unquote(body)
    end
  end

  defp option_types(schema, kind) do
    schema
    |> Enum.sort_by(fn {name, _variants} -> name end)
    |> Enum.map(fn {name, variants} ->
      types = variants |> Enum.flat_map(&value_types/1) |> Enum.uniq()

      types =
        if kind in [:encoder, :muxer] do
          types ++ [quote(do: FFix.Command.option_callback())]
        else
          types
        end

      quote do: {unquote(String.to_atom(name)), unquote(union(types))}
    end)
  end

  defp value_types(%{type: type, constants: constants}) do
    symbols = Enum.map(constants, &String.to_atom/1)

    types =
      case type do
        type when type in [:int, :int64, :uint64, :unsigned] ->
          [quote(do: integer()), quote(do: String.t())]

        type when type in [:float, :double, :duration, :rational, :video_rate] ->
          [quote(do: number()), quote(do: String.t())]

        :boolean ->
          [quote(do: boolean()), :auto, quote(do: String.t())]

        :flags ->
          flags = union([quote(do: String.t()) | symbols])
          [quote(do: integer()), quote(do: String.t()), quote(do: [unquote(flags)])]

        {:unknown, _name} ->
          [quote(do: String.t()), quote(do: number()), quote(do: boolean()), quote(do: atom())]

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
          [quote(do: String.t()), quote(do: atom())]

        _other ->
          [quote(do: String.t())]
      end

    types ++ symbols
  end

  defp special_types(kind) do
    common =
      if kind in [:encoder, :muxer] do
        [quote(do: {:raw, [FFix.Command.output_av_option()]})]
      else
        [quote(do: {:raw, [FFix.Command.av_option()]})]
      end

    case kind do
      :muxer ->
        common ++ [quote(do: {:output_options, [FFix.Command.option()]})]

      :demuxer ->
        common ++ [quote(do: {:input_options, [FFix.Command.option()]})]

      _codec ->
        common
    end
  end

  defp union(types) do
    types
    |> Enum.reverse()
    |> Enum.reduce(fn type, combined -> quote(do: unquote(type) | unquote(combined)) end)
  end

  defp documentation(entry, name, options) do
    {role, guide} =
      case entry.kind do
        :encoder -> {"Encodes the selected streams with `#{name}`.", "FFix.Encoder"}
        :decoder -> {"Configures #{entry.media_type} decoding on an input.", "FFix.Decoder"}
        :muxer -> {"Declares an output in #{name} format.", "FFix.Muxer"}
        :demuxer -> {"Declares an input in #{name} format.", "FFix.Demuxer"}
      end

    counts = Enum.frequencies_by(options, fn {_owner, option} -> option.name end)

    rows =
      Enum.map_join(options, "\n", fn {owner, option} ->
        origin =
          if counts[option.name] > 1 do
            " — #{owner}"
          else
            ""
          end

        constants = Enum.map_join(option.constants, ", ", &"`#{&1.name}`")

        suffix =
          if constants == "" do
            ""
          else
            " Values: #{constants}."
          end

        "- `#{option.name}` (#{option_type(option.type)})#{origin}" <>
          description_suffix(option.help, ": ") <> suffix
      end)

    properties =
      Enum.map_join(entry.properties, "\n", fn {label, value} -> "- #{label}: #{value}" end)

    example = component_example(entry.kind, name)

    example =
      if example do
        "## Example\n\n    #{example}\n"
      else
        ""
      end

    properties =
      if properties == "" do
        ""
      else
        "## Format and codec details\n\n#{properties}\n"
      end

    rows =
      if rows == "" do
        "This helper has no listed format-specific options."
      else
        rows
      end

    """
    #{entry.description}

    #{role} See `#{guide}` for usage and option conventions.

    #{example}
    ## Options

    #{rows}

    #{properties}
    """
    |> String.split("\n")
    |> Enum.map_join("\n", &String.trim_trailing/1)
    |> String.trim()
  end

  defp component_example(kind, name) do
    examples = %{
      {:encoder, "libx264"} => ~s|FFix.Encoder.libx264(video, crf: 23, preset: "medium")|,
      {:encoder, "aac"} => ~s|FFix.Encoder.aac(audio, b: "128k")|,
      {:encoder, "libopus"} => ~s|FFix.Encoder.libopus(audio, b: "96k")|,
      {:encoder, "ffv1"} => ~s|FFix.Encoder.ffv1(video)|,
      {:decoder, "h264"} => ~s|FFix.Decoder.h264(input, {:video, 0}, threads: 2)|,
      {:decoder, "aac"} => ~s|FFix.Decoder.aac(input, {:audio, 0})|,
      {:muxer, "mp4"} => ~s|FFix.Muxer.mp4(sources, "interview.mp4", movflags: [:faststart])|,
      {:muxer, "matroska"} => ~s|FFix.Muxer.matroska(sources, "archive.mkv")|,
      {:muxer, "hls"} => ~s|FFix.Muxer.hls(sources, "hls/index.m3u8", hls_time: 4)|,
      {:muxer, "null"} => ~s|FFix.Muxer.null(sources, :stdout)|,
      {:demuxer, "rawvideo"} =>
        ~s|FFix.Demuxer.rawvideo("frames.rgb", video_size: "640x480", pixel_format: "rgb24", framerate: 30)|,
      {:demuxer, "lavfi"} => ~s|FFix.Demuxer.lavfi("testsrc2=size=640x360:duration=2")|
    }

    Map.get(examples, {kind, name})
  end

  def description_suffix(description, separator) do
    case String.trim(description || "") do
      "" -> ""
      text -> separator <> text
    end
  end

  def option_type({:array, type}), do: "#{option_type(type)} list"
  def option_type({:unknown, name}), do: name
  def option_type(type), do: to_string(type)
end
