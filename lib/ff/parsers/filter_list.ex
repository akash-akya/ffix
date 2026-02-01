defmodule FF.Parsers.FilterList do
  @moduledoc false

  import NimbleParsec

  ws = utf8_string([?\s, ?\t], min: 1)

  name = utf8_string([?a..?z, ?0..?9, ?_], min: 1)

  io =
    times(
      choice([
        string("A"),
        string("V"),
        string("N"),
        string("|")
      ]),
      min: 1,
      max: 5
    )
    |> map({String, :to_atom, []})
    |> wrap()

  mapping =
    io
    |> ignore(string("->"))
    |> concat(io)
    |> reduce({List, :to_tuple, []})

  null = ignore(string("."))

  support =
    choice([string("T"), null])
    |> choice([string("S"), null])
    |> optional(choice([string("C"), null]))
    |> map({String, :to_atom, []})
    |> wrap()

  line =
    ignore(ws)
    |> concat(support)
    |> ignore(ws)
    |> concat(name)
    |> ignore(ws)
    |> concat(mapping)
    |> ignore(ws)
    |> utf8_string([], min: 1)

  defparsec(:filter_list, line)

  def parse(line) do
    {:ok, parsed, "", %{}, _, _} = filter_list(line)
    parsed
  end
end
