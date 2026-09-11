defmodule FFix.Parsers.ComponentHelp do
  @moduledoc false

  import NimbleParsec

  alias FFix.Discovery.Error
  alias FFix.Parsers.AVOptions
  alias FFix.Parsers.Lines

  @shared ~w(AVCodecContext AVFormatContext AVIOContext URLContext)

  whitespace = ignore(ascii_string([?\s, ?\t], min: 1))
  padding = optional(whitespace)
  name = utf8_string([{:not, ?\s}, {:not, ?\t}], min: 1)
  text = utf8_string([], min: 0)

  component_kind =
    choice([
      replace(string("Encoder "), :encoder),
      replace(string("Decoder "), :decoder),
      replace(string("Muxer "), :muxer),
      replace(string("Demuxer "), :demuxer)
    ])

  description =
    repeat(lookahead_not(string("]:") |> eos()) |> utf8_string([], 1))
    |> reduce({Enum, :join, [""]})

  component_header =
    component_kind
    |> concat(name)
    |> ignore(string(" ["))
    |> concat(description)
    |> ignore(string("]:"))

  simple_header =
    choice([
      replace(string("Filter "), :filter),
      replace(string("Bit stream filter "), :bitstream_filter)
    ])
    |> concat(name)
    |> replace(empty(), nil)

  component =
    choice([component_header, simple_header])
    |> reduce({__MODULE__, :identity, []})
    |> unwrap_and_tag(:component)

  option_section =
    repeat(lookahead_not(string(" AVOptions:") |> eos()) |> utf8_string([], 1))
    |> reduce({Enum, :join, [""]})
    |> ignore(string(" AVOptions:"))
    |> unwrap_and_tag(:section)

  unavailable =
    choice([string("Unknown "), string("Codec ")])
    |> concat(text)
    |> reduce({Enum, :join, [""]})
    |> unwrap_and_tag(:unavailable)

  defparsecp(
    :heading,
    choice([component, option_section, unavailable, unwrap_and_tag(text, :note)]) |> eos()
  )

  pad_name =
    repeat(lookahead_not(string(" (")) |> utf8_string([], 1))
    |> reduce({Enum, :join, [""]})

  pad =
    ignore(string("#"))
    |> integer(min: 1)
    |> ignore(string(": "))
    |> concat(pad_name)
    |> ignore(string(" ("))
    |> utf8_string([{:not, ?)}], min: 1)
    |> ignore(string(")"))
    |> concat(padding)
    |> reduce({__MODULE__, :pad, []})
    |> unwrap_and_tag(:pad)

  pad_heading =
    choice([replace(string("Inputs:"), :inputs), replace(string("Outputs:"), :outputs)])
    |> unwrap_and_tag(:pads)

  dynamic_pads =
    string("dynamic ") |> concat(text) |> reduce({Enum, :join, [""]}) |> unwrap_and_tag(:dynamic)

  no_pads =
    choice([string("none (source filter)"), string("none (sink filter)")])
    |> replace({:no_pads, true})

  property =
    utf8_string([{:not, ?:}], min: 1)
    |> ignore(string(":"))
    |> concat(padding)
    |> concat(text)
    |> reduce({List, :to_tuple, []})
    |> unwrap_and_tag(:property)

  note =
    lookahead_not(choice([string("#"), string("-")])) |> concat(text) |> unwrap_and_tag(:note)

  defparsecp(
    :field,
    whitespace |> choice([pad_heading, pad, dynamic_pads, no_pads, property, note]) |> eos()
  )

  def parse!(kind, text) do
    # FFmpeg's unindented headings delimit option owners; indentation groups their rows.
    blocks = text |> Lines.read() |> Lines.blocks()
    {info, blocks} = component_info(kind, blocks)
    contents = Enum.map(blocks, &content/1)
    sections = Keyword.get_values(contents, :section)
    notes = info.notes ++ List.flatten(Keyword.get_values(contents, :notes))

    if kind == :protocol and sections == [] do
      Lines.invalid!("missing protocol option section")
    end

    Map.merge(info, %{option_sections: sections, notes: notes})
  end

  def shared!(text) do
    blocks = text |> Lines.read() |> Lines.blocks()
    sections = Enum.flat_map(blocks, &shared_section/1)

    if sections == [] do
      Lines.invalid!("missing shared AVOptions sections")
    end

    sections
  end

  defp shared_section([header | rows]) do
    case Lines.parse!(&heading/1, header) do
      [section: name] when name in @shared ->
        [section(name, rows)]

      _other ->
        []
    end
  end

  defp component_info(kind, blocks) do
    case {kind, blocks} do
      {:protocol, _blocks} ->
        # Protocol help identifies AVClasses, not protocol registrations.
        info = %{kind: :protocol, names: [], description: nil, properties: [], notes: []}
        {info, blocks}

      {_kind, []} ->
        Lines.invalid!("empty component help")

      {_kind, [block | remaining_blocks]} ->
        {component_block(kind, block), remaining_blocks}
    end
  end

  defp component_block(kind, [header | rows]) do
    case Lines.parse!(&heading/1, header) do
      [component: %{kind: ^kind} = identity] -> info(identity, rows)
      [unavailable: message] -> unavailable!(message)
      _other -> Lines.invalid!("expected #{kind} help", header)
    end
  end

  defp info(identity, rows) do
    case {identity.kind, rows} do
      {:filter, [{"  " <> description, _number} | remaining_rows]} ->
        identity = %{identity | description: String.trim(description)}
        fields(identity, remaining_rows)

      _other ->
        fields(identity, rows)
    end
  end

  defp fields(identity, rows) do
    fields =
      Enum.map(rows, fn line ->
        [parsed_field] = Lines.parse!(&field/1, line)
        parsed_field
      end)

    identity
    |> Map.put(:properties, Keyword.get_values(fields, :property))
    |> Map.put(:notes, Keyword.get_values(fields, :note))
    |> put_pads(fields)
  end

  defp put_pads(info, fields) do
    case info.kind do
      :filter ->
        Enum.reduce([:inputs, :outputs], info, fn direction, info ->
          {pads, dynamic_description} = pads(fields, direction)
          info = Map.put(info, direction, pads)

          # Mixed declarations keep fixed pad lists; only those directions get extra metadata.
          case dynamic_description do
            nil ->
              info

            description ->
              Map.update(info, :dynamic_pads, %{direction => description}, fn dynamic_pads ->
                Map.put(dynamic_pads, direction, description)
              end)
          end
        end)

      _other ->
        info
    end
  end

  defp pads(fields, direction) do
    fields |> Enum.drop_while(&(&1 != {:pads, direction})) |> pad_values()
  end

  defp pad_values(fields) do
    case fields do
      [] ->
        {nil, nil}

      [_heading | remaining_fields] ->
        pad_fields =
          Enum.take_while(remaining_fields, fn {kind, _value} ->
            kind in [:pad, :dynamic]
          end)

        fixed_pads = Keyword.get_values(pad_fields, :pad)
        dynamic_description = Keyword.get(pad_fields, :dynamic)

        case {fixed_pads, dynamic_description} do
          {[], description} when is_binary(description) ->
            {%{dynamic: description}, nil}

          _other ->
            {fixed_pads, dynamic_description}
        end
    end
  end

  defp content([header | rows]) do
    case Lines.parse!(&heading/1, header) do
      [section: name] -> {:section, section(name, rows)}
      [note: _text] -> {:notes, Enum.map([header | rows], fn {text, _} -> String.trim(text) end)}
      [unavailable: message] -> unavailable!(message)
      [component: _identity] -> Lines.invalid!("expected help for one implementation", header)
    end
  end

  defp section(name, rows), do: %{name: name, options: AVOptions.parse_rows!(rows)}

  defp unavailable!(message) do
    raise Error, reason: :help_unavailable, message: message
  end

  def identity([kind, names, description]) do
    %{kind: kind, names: String.split(names, ","), description: description}
  end

  def pad([index, name, media]), do: %{index: index, name: name, media_type: media}
end
