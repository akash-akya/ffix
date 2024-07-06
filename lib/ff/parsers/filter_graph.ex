defmodule FF.Parsers.FilterGraph do
  import NimbleParsec

  @alphanum [?a..?z, ?A..?Z, ?_, ?0..?9]

  name =
    ascii_string(@alphanum, min: 1)
    |> reduce({Enum, :join, [""]})

  filter_name =
    name
    |> optional(string("@") |> concat(name))

  link_label =
    ignore(string("["))
    |> concat(name)
    |> ignore(string("]"))

  link_labels =
    link_label
    |> optional(repeat(link_label))
    |> wrap()

  quoted_string =
    ignore(string("'"))
    |> utf8_string([{:not, ?'}], min: 0)
    |> ignore(string("'"))
    |> reduce({Enum, :join, [""]})

  @allowed_arg_chars @alphanum ++ [?-, ?+, ?., ?/, ?\s, ?\t]

  string =
    choice([
      ascii_string(@allowed_arg_chars, min: 1),
      quoted_string
    ])

  list =
    string
    |> times(ignore(string("|")) |> concat(string), min: 1)
    |> wrap()

  filter_value =
    choice([
      list,
      string
    ])

  filter_key = string

  filter_pair =
    filter_key
    |> ignore(string("="))
    |> concat(filter_value)
    |> reduce({List, :to_tuple, []})

  filter_arg =
    choice([
      filter_pair,
      filter_value
    ])

  args =
    ignore(string("="))
    |> repeat(filter_arg |> ignore(string(":")))
    |> concat(filter_arg)
    |> wrap()

  # FILTER           ::= [LINKLABELS] FILTER_NAME ["=" FILTER_ARGUMENTS] [LINKLABELS]
  filter =
    optional(link_labels)
    |> concat(filter_name)
    |> optional(args)
    |> optional(link_labels)

  # FILTERCHAIN      ::= FILTER [,FILTERCHAIN]
  filter_chain =
    filter
    |> repeat(ignore(string(",")) |> concat(filter))

  # FILTERGRAPH      ::= [sws_flags=flags;] FILTERCHAIN [;FILTERGRAPH]
  filter_graph =
    filter_chain
    |> repeat(ignore(string(";")) |> concat(filter_chain))

  defparsec(:filter_graph, filter_graph)

  def parse(line) do
    {:ok, parsed, "", %{}, _, _} = filter_graph(line)
    parsed
  end
end
