defmodule FF.Parsers.FilterSpec do
  import NimbleParsec

  @alpha_num [?a..?z, ?A..?Z, ?0..?9, ?_]

  type =
    choice([
      string("binary"),
      string("boolean"),
      string("channel_layout"),
      string("color"),
      string("dictionary"),
      string("double"),
      string("duration"),
      string("flags"),
      string("float"),
      string("image_size"),
      string("int64"),
      string("int"),
      string("pix_fmt"),
      string("rational"),
      string("sample_fmt"),
      string("string"),
      string("video_rate")
    ])
    |> map({String, :to_atom, []})

  ws = utf8_string([?\s, ?\t], min: 1)

  param_type =
    ignore(string("<"))
    |> concat(type)
    |> ignore(string(">"))
    |> unwrap_and_tag(:type)

  number = utf8_string([?0..?9, ?-], min: 1)

  flags = utf8_string([?A..?Z, ?\.], 11)

  opt =
    choice([
      param_type,
      number
    ])

  param_name = utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-], min: 1)

  desc = utf8_string(@alpha_num ++ [?\s, ?\., ?(, ?), ?", ?', ?/, ?+, ?-, ?;], min: 0)

  depth =
    times(utf8_char([?\s]), min: 1)
    |> reduce({Enum, :count, []})
    |> unwrap_and_tag(:depth)

  line =
    depth
    |> concat(param_name)
    |> ignore(ws)
    |> concat(
      choice([
        opt |> ignore(ws),
        utf8_string([], 0)
      ])
    )
    |> concat(flags)
    |> optional(ignore(ws))
    |> concat(desc)

  defparsec(:filter_spec, line)

  def parse(line) do
    {:ok, parsed, "", %{}, _, _} = filter_spec(line)
    parsed
  end
end
