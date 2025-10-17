defmodule FF.Parsers.FilterSpec do
  import NimbleParsec

  @alpha_num [?a..?z, ?A..?Z, ?0..?9, ?_]

  @param_name_char [?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?+, ?>, ?&]

  ws = utf8_string([?\s, ?\t], min: 1)

  core_type =
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
      string("video_rate"),
      string("unsigned"),
      string("sample_fmt")
    ])

  type =
    ignore(string("<"))
    |> concat(core_type)
    |> ignore(string(">"))
    |> map({String, :to_atom, []})

  array =
    ignore(string("["))
    |> concat(type)
    |> optional(ignore(ws))
    |> ignore(string("]"))
    |> unwrap_and_tag(:array)

  param_type =
    choice([
      type,
      array
    ])
    |> unwrap_and_tag(:type)

  number = utf8_string([?0..?9, ?-], min: 1)

  flags = utf8_string([?\., ?F, ?V, ?P, ?A, ?T, ?X, ?R], 11)

  opt =
    choice([
      param_type,
      number
    ])

  param_char = utf8_char(@param_name_char)

  param_name =
    param_char
    |> repeat(
      choice([
        param_char,
        # if next char is space then the subsequent char must be param-char
        utf8_char([?\s]) |> lookahead(param_char)
      ])
    )
    |> reduce({List, :to_string, []})

  desc =
    utf8_string(
      @alpha_num ++
        [
          ?\s,
          ?\.,
          ?(,
          ?),
          ?",
          ?',
          ?/,
          ?+,
          ?-,
          ?;,
          ?,,
          ?µ,
          ?|,
          ?:,
          ?*,
          ?#,
          ?>,
          ?<,
          ?=,
          ?°,
          ??,
          ?&,
          ?[,
          ?],
          ?!,
          ?~,
          ?%,
          ?{,
          ?},
          ?\\,
          ?$,
          ?@
        ],
      min: 0
    )

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
        opt |> optional(ignore(ws)),
        utf8_string([], 0)
      ])
    )
    |> concat(flags)
    |> optional(ignore(ws))
    |> optional(desc)

  defparsec(:filter_spec, line)

  def parse(line) do
    # dbg(line)
    {:ok, parsed, "", %{}, _, _} = filter_spec(line)
    parsed
  end
end
