defmodule FFix.Parsers.DiscoveryList do
  @moduledoc false

  import NimbleParsec

  alias FFix.Parsers.Lines

  whitespace = ignore(ascii_string([?\s, ?\t], min: 1))
  padding = optional(whitespace)
  name = utf8_string([{:not, ?\s}, {:not, ?\t}], min: 1)
  description = utf8_string([], min: 0)
  flag_chars = [?A..?Z, ?a..?z, ?.]
  name_description = name |> concat(padding) |> concat(description)

  defparsecp(:name_row, padding |> concat(name) |> concat(padding) |> eos())
  defparsecp(:description_row, padding |> concat(name_description) |> eos())

  defparsecp(
    :separator,
    padding |> ignore(ascii_string([?-], min: 2)) |> concat(padding) |> eos()
  )

  codec = padding |> ascii_string(flag_chars, 6) |> concat(whitespace) |> concat(name_description)
  defparsecp(:codec_row, codec |> eos())

  format_tail = whitespace |> concat(name_description) |> eos()
  format_flags = flag_chars ++ [?\s]

  # The entire row is an alternative: a missing third flag must not consume the name separator.
  format =
    choice([
      ignore(string(" ")) |> ascii_string(format_flags, 3) |> concat(format_tail),
      ignore(string(" ")) |> ascii_string(format_flags, 2) |> concat(format_tail)
    ])

  defparsecp(:format_row, format)

  pads = ascii_string([?A..?Z, ?|], min: 1)

  filter =
    padding
    |> ascii_string(flag_chars, 3)
    |> concat(whitespace)
    |> concat(name)
    |> concat(whitespace)
    |> concat(pads)
    |> ignore(string("->"))
    |> concat(pads)
    |> concat(padding)
    |> concat(description)

  defparsecp(:filter_row, filter |> eos())

  bit_depths = integer(min: 1) |> repeat(ignore(string("-")) |> integer(min: 1)) |> wrap()

  pixel_format =
    padding
    |> ascii_string(flag_chars, 5)
    |> concat(whitespace)
    |> concat(name)
    |> concat(whitespace)
    |> integer(min: 1)
    |> concat(whitespace)
    |> integer(min: 1)
    |> optional(whitespace |> concat(bit_depths))
    |> concat(padding)

  defparsecp(:pixel_format_row, pixel_format |> eos())

  defparsecp(
    :sample_format_row,
    padding |> concat(name) |> concat(whitespace) |> integer(min: 1) |> concat(padding) |> eos()
  )

  rgb = string("#") |> ascii_string([?0..?9, ?a..?f, ?A..?F], 6) |> reduce({Enum, :join, [""]})

  defparsecp(
    :color_row,
    padding |> concat(name) |> concat(whitespace) |> concat(rgb) |> concat(padding) |> eos()
  )

  @table_headers %{
    encoder: "Encoders:",
    decoder: "Decoders:",
    codec: "Codecs:",
    muxer: ["Formats:", "File formats:"],
    demuxer: ["Formats:", "File formats:"],
    format: ["Formats:", "File formats:"],
    device: "Devices:",
    pixel_format: "Pixel formats:"
  }

  @list_headers %{
    bitstream_filter: "Bitstream filters:",
    hardware_acceleration: "Hardware acceleration methods:",
    sample_format: "name depth",
    color: "name #RRGGBB"
  }

  def parse!(kind, text) do
    entries = text |> Lines.read() |> catalog(kind) |> Enum.map(&Map.put(&1, :kind, kind))
    check_names!(entries)
    entries
  end

  defp catalog(lines, kind) do
    case kind do
      :protocol -> protocol_catalog(lines)
      _other -> lines |> rows(kind) |> Enum.map(&entry(kind, &1))
    end
  end

  defp protocol_catalog(lines) do
    registrations =
      lines
      |> Lines.after_header("Supported file protocols:")
      |> Lines.blocks()
      |> Enum.flat_map(&protocol_section/1)

    directions_by_name = Enum.group_by(registrations, &elem(&1, 0), &elem(&1, 1))
    unique_registrations = Enum.uniq_by(registrations, &elem(&1, 0))

    Enum.map(unique_registrations, fn {name, _direction} ->
      directions = Map.fetch!(directions_by_name, name)
      %{names: [name], directions: directions}
    end)
  end

  defp rows(lines, kind) do
    case kind do
      kind when is_map_key(@table_headers, kind) ->
        lines |> Lines.after_header(@table_headers[kind]) |> table_rows()

      kind when is_map_key(@list_headers, kind) ->
        Lines.after_header(lines, @list_headers[kind])

      :disposition ->
        lines

      :filter ->
        lines |> Lines.after_header("Filters:") |> Enum.drop_while(&legend?/1)

      :channel ->
        lines
        |> Lines.after_header("Individual channels:")
        |> Enum.take_while(fn {line, _} -> line != "Standard channel layouts:" end)
        |> Lines.after_header("NAME DESCRIPTION")

      :channel_layout ->
        lines
        |> Lines.after_header("Standard channel layouts:")
        |> Lines.after_header("NAME DECOMPOSITION")
    end
  end

  defp table_rows(lines) do
    case Enum.drop_while(lines, &(not separator?(&1))) do
      [_separator | rows] -> rows
      [] -> Lines.invalid!("missing registry table separator")
    end
  end

  defp separator?({text, _number}), do: match?({:ok, [], "", _, _, _}, separator(text))
  defp legend?({text, _number}), do: match?([_flag, "=" | _description], String.split(text))

  defp entry(kind, line) do
    case kind do
      kind when kind in [:encoder, :decoder, :codec] ->
        [flags, name, description] = Lines.parse!(&codec_row/1, line)

        %{names: [name], flags: flags, description: description}
        |> Map.merge(codec_info(kind, flags, description))

      kind when kind in [:muxer, :demuxer, :format, :device] ->
        [flags, names, description] = Lines.parse!(&format_row/1, line)

        %{
          names: String.split(names, ","),
          description: description,
          flags: flags,
          directions: directions(flags),
          device?: device?(kind, flags)
        }

      :filter ->
        [flags, name, inputs, outputs, description] = Lines.parse!(&filter_row/1, line)
        %{names: [name], description: description, flags: flags, inputs: inputs, outputs: outputs}

      :pixel_format ->
        [flags, name, components, bits | depths] = Lines.parse!(&pixel_format_row/1, line)

        %{
          names: [name],
          flags: flags,
          components: components,
          bits_per_pixel: bits,
          bit_depths: List.first(depths)
        }

      :sample_format ->
        [name, depth] = Lines.parse!(&sample_format_row/1, line)
        %{names: [name], bit_depth: depth}

      :color ->
        [name, rgb] = Lines.parse!(&color_row/1, line)
        %{names: [name], rgb: rgb}

      :channel ->
        [name, description] = Lines.parse!(&description_row/1, line)
        %{names: [name], description: description}

      :channel_layout ->
        [name, decomposition] = Lines.parse!(&description_row/1, line)
        %{names: [name], decomposition: decomposition}

      kind when kind in [:bitstream_filter, :hardware_acceleration, :disposition] ->
        [name] = Lines.parse!(&name_row/1, line)
        %{names: [name]}
    end
  end

  defp codec_info(kind, flags, description) do
    case {kind, flags} do
      {:codec, <<_decoder, _encoder, media, _rest::binary>>} ->
        %{
          media_type: media_type(media),
          decoders: implementations(description, "decoders:"),
          encoders: implementations(description, "encoders:")
        }

      {_implementation, <<media, _rest::binary>>} ->
        %{media_type: media_type(media), codec: annotation(description, "codec")}
    end
  end

  defp implementations(description, label) do
    case annotation(description, label) do
      nil -> nil
      names -> String.split(names)
    end
  end

  defp annotation(description, label) do
    with [_prefix, rest] <- String.split(description, "(" <> label <> " ", parts: 2),
         [value, _suffix] <- String.split(rest, ")", parts: 2) do
      String.trim(value)
    else
      _ -> nil
    end
  end

  defp media_type(flag) do
    case flag do
      ?V -> :video
      ?A -> :audio
      ?S -> :subtitle
      ?D -> :data
      ?T -> :attachment
      other -> {:unknown, <<other>>}
    end
  end

  defp directions(flags) do
    case flags do
      <<"DE", _rest::binary>> -> [:input, :output]
      <<"D", _rest::binary>> -> [:input]
      <<_input, ?E, _rest::binary>> -> [:output]
      _other -> []
    end
  end

  defp device?(kind, flags) do
    case {kind, flags} do
      {:device, _flags} -> true
      {_kind, <<_input, _output>>} -> nil
      {_kind, <<_input, _output, flag>>} -> flag == ?d
    end
  end

  defp protocol_section(section) do
    case section do
      [{"Input:", _number} | rows] -> protocol_rows(rows, :input)
      [{"Output:", _number} | rows] -> protocol_rows(rows, :output)
      [line | _rows] -> Lines.invalid!("expected protocol direction", line)
    end
  end

  defp protocol_rows(rows, direction) do
    Enum.map(rows, fn row ->
      [name] = Lines.parse!(&name_row/1, row)
      {name, direction}
    end)
  end

  defp check_names!(entries) do
    keys = Enum.flat_map(entries, &registration_keys/1)
    unique_keys = Enum.uniq(keys)

    if length(keys) != length(unique_keys) do
      Lines.invalid!("duplicate registry name")
    end
  end

  defp registration_keys(entry) do
    # Combined formats may register the same alias once per direction.
    directions = Map.get(entry, :directions, [nil])

    Enum.flat_map(directions, fn direction ->
      scoped_names(entry.names, direction)
    end)
  end

  defp scoped_names(names, direction) do
    Enum.map(names, fn name ->
      {name, direction}
    end)
  end
end
