defmodule FFix.Parsers.AVOptions do
  @moduledoc false

  import NimbleParsec

  alias FFix.Parsers.Lines

  @types ~w(binary boolean channel_layout color dictionary double duration flags float image_size int int64 pix_fmt rational sample_fmt string unsigned uint64 video_rate)a
  @type_names Map.new(@types, &{Atom.to_string(&1), &1})

  whitespace = ignore(ascii_string([?\s, ?\t], min: 1))
  padding = optional(whitespace)
  name = utf8_string([{:not, ?\s}, {:not, ?\t}], min: 1)
  help = utf8_string([], min: 0)
  flags = ascii_string([?A..?Z, ?a..?z, ?.], min: 11)
  boundary = choice([whitespace, eos()])

  scalar_type =
    ignore(string("<"))
    |> utf8_string([{:not, ?>}], min: 1)
    |> ignore(string(">"))
    |> map({__MODULE__, :type, []})

  array_type =
    ignore(string("["))
    |> concat(padding)
    |> concat(scalar_type)
    |> concat(padding)
    |> ignore(string("]"))
    |> map({__MODULE__, :array_type, []})

  option =
    whitespace
    |> ignore(optional(string("-")))
    |> concat(name)
    |> concat(whitespace)
    |> concat(choice([array_type, scalar_type]))
    |> concat(padding)
    |> concat(flags)
    |> concat(padding)
    |> concat(help)
    |> reduce({__MODULE__, :option, []})
    |> unwrap_and_tag(:option)

  sign = optional(choice([string("-"), string("+")]))
  digits = ascii_string([?0..?9], min: 1)
  exponent = choice([string("e"), string("E")]) |> concat(sign) |> concat(digits)

  number =
    sign
    |> concat(digits)
    |> optional(string(".") |> ascii_string([?0..?9], min: 0))
    |> optional(exponent)
    |> reduce({Enum, :join, [""]})

  constant_columns =
    choice([
      replace(empty(), nil) |> concat(flags),
      number |> concat(whitespace) |> concat(flags)
    ])
    |> lookahead(boundary)

  defcombinatorp(:constant_columns, constant_columns)

  constant_word = utf8_string([{:not, ?\s}, {:not, ?\t}, {:not, ?<}, {:not, ?[}], min: 1)

  # Names such as "deep bass" contain spaces; the value/flags columns end the name.
  constant_name =
    constant_word
    |> repeat(string(" ") |> lookahead_not(parsec(:constant_columns)) |> concat(constant_word))
    |> reduce({Enum, :join, [""]})

  constant =
    whitespace
    |> concat(constant_name)
    |> concat(whitespace)
    |> parsec(:constant_columns)
    |> concat(padding)
    |> concat(help)
    |> reduce({__MODULE__, :constant, []})
    |> unwrap_and_tag(:constant)

  defparsecp(:row, choice([option, constant]) |> eos())

  quoted_value =
    string("\"")
    |> repeat(
      choice([
        string("\\") |> utf8_string([], 1),
        utf8_string([{:not, ?"}, {:not, ?\\}], min: 1)
      ])
    )
    |> string("\"")
    |> reduce({Enum, :join, [""]})

  default =
    ignore(string(" (default "))
    |> concat(choice([quoted_value, utf8_string([{:not, ?(}, {:not, ?)}], min: 1)]))
    |> ignore(string(")"))
    |> unwrap_and_tag(:default)

  bound = utf8_string([{:not, ?\s}, {:not, ?)}], min: 1)

  range =
    ignore(string(" (from "))
    |> concat(bound)
    |> ignore(string(" to "))
    |> concat(bound)
    |> ignore(string(")"))
    |> tag(:range)

  suffix = choice([times(range, min: 1) |> optional(default), default]) |> eos()
  defcombinatorp(:annotation_suffix, suffix)

  # Only terminal annotations are metadata; similar text inside a description is prose.
  description = repeat(lookahead_not(parsec(:annotation_suffix)) |> utf8_char([])) |> ignore()
  defparsecp(:annotations, description |> optional(parsec(:annotation_suffix)) |> eos())

  def parse_rows!(lines) do
    lines
    |> Enum.map(&parse_row/1)
    |> group_options()
  end

  defp parse_row(line) do
    [entry] = Lines.parse!(&row/1, line)
    {entry, line}
  end

  defp group_options([]), do: []

  defp group_options([{{:option, option}, _line} | rows]) do
    {constant_rows, rest} = Enum.split_while(rows, &match?({{:constant, _}, _}, &1))

    constants =
      Enum.map(constant_rows, fn {{:constant, constant}, _line} ->
        constant
      end)

    option = %{option | constants: constants}
    [option | group_options(rest)]
  end

  defp group_options([{{:constant, _value}, line} | _rest]) do
    Lines.invalid!("option constant has no parent option", line)
  end

  def type(name), do: Map.get(@type_names, name, {:unknown, name})
  def array_type(type), do: {:array, type}

  def option([name, type, flags, help]) do
    {:ok, annotations, "", _, _, _} = annotations(" " <> help)

    ranges =
      annotations
      |> Keyword.get_values(:range)
      |> Enum.map(fn [minimum, maximum] ->
        %{min: minimum, max: maximum}
      end)

    %{
      name: name,
      type: type,
      flags: flags,
      help: help,
      declared_default: Keyword.get(annotations, :default),
      ranges: ranges,
      constants: []
    }
  end

  def constant([name, value, flags, help]) do
    %{name: name, value: value, flags: flags, help: help}
  end
end
