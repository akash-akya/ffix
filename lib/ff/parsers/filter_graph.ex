defmodule FF.Parsers.FilterGraph do
  @moduledoc false

  import NimbleParsec

  @name_chars [?a..?z, ?A..?Z, ?0..?9, ?_]
  @ws_chars [?\n, ?\r, ?\t, ?\s]

  whitespace = ascii_string(@ws_chars, min: 1)
  maybe_whitespace = ignore(optional(whitespace))

  label =
    ignore(string("["))
    |> concat(utf8_string([{:not, ?]}], min: 1))
    |> ignore(string("]"))

  labels =
    times(
      maybe_whitespace
      |> concat(label)
      |> concat(maybe_whitespace),
      min: 1
    )

  name = ascii_string(@name_chars, min: 1)

  filter_name =
    name
    |> optional(ignore(string("@")) |> concat(name))
    |> wrap()
    |> tag(:filter_name)

  escaped_piece =
    string("\\")
    |> concat(utf8_string([], 1))
    |> reduce({Enum, :join, [""]})

  quoted_piece =
    string("'")
    |> repeat(
      choice([
        escaped_piece,
        utf8_string([{:not, ?'}], min: 1)
      ])
    )
    |> string("'")
    |> reduce({Enum, :join, [""]})

  arg_char =
    lookahead_not(choice([string("["), string(","), string(";")]))
    |> utf8_string([], 1)

  raw_args =
    repeat(choice([quoted_piece, escaped_piece, arg_char]))
    |> reduce({Enum, :join, [""]})

  args =
    ignore(string("="))
    |> concat(maybe_whitespace)
    |> concat(raw_args)
    |> wrap()
    |> tag(:args)

  inputs = labels |> tag(:inputs)
  outputs = labels |> tag(:outputs)

  filter =
    maybe_whitespace
    |> concat(optional(inputs))
    |> concat(maybe_whitespace)
    |> concat(filter_name)
    |> concat(maybe_whitespace)
    |> concat(optional(args))
    |> concat(maybe_whitespace)
    |> concat(optional(outputs))
    |> concat(maybe_whitespace)
    |> reduce({__MODULE__, :build_filter, []})

  chain_separator = maybe_whitespace |> ignore(string(",")) |> concat(maybe_whitespace)
  graph_separator = maybe_whitespace |> ignore(string(";")) |> concat(maybe_whitespace)

  chain =
    filter
    |> repeat(chain_separator |> concat(filter))
    |> reduce({__MODULE__, :build_chain, []})

  setting_value_char =
    lookahead_not(string(";"))
    |> utf8_string([], 1)

  setting_value =
    repeat(choice([quoted_piece, escaped_piece, setting_value_char]))
    |> reduce({Enum, :join, [""]})

  setting =
    maybe_whitespace
    |> ignore(string("sws_flags"))
    |> concat(maybe_whitespace)
    |> ignore(string("="))
    |> concat(maybe_whitespace)
    |> concat(setting_value)
    |> concat(maybe_whitespace)
    |> reduce({__MODULE__, :build_setting, []})

  statement = choice([setting, chain])

  graph =
    statement
    |> repeat(graph_separator |> concat(statement))
    |> ignore(optional(graph_separator))

  defparsec(:filter_graph, graph)

  @spec parse(String.t()) :: [tuple()]
  def parse(source) when is_binary(source) do
    case filter_graph(source) do
      {:ok, parsed, "", %{}, _, _} -> parsed
      {:ok, _parsed, rest, %{}, _, _} -> raise ArgumentError, "unexpected trailing input: #{inspect(rest)}"
      {:error, message, rest, %{}, _, _} -> raise ArgumentError, "#{message} at #{inspect(rest)}"
    end
  end

  def build_filter(parts) do
    Enum.reduce(parts, %{inputs: [], name: nil, instance: nil, args: nil, outputs: []}, fn
      {:inputs, labels}, filter ->
        %{filter | inputs: labels}

      {:outputs, labels}, filter ->
        %{filter | outputs: labels}

      {:filter_name, values}, filter ->
        case List.flatten(values) do
          [name] -> %{filter | name: name}
          [name, instance] -> %{filter | name: name, instance: instance}
        end

      {:args, values}, filter ->
        args = values |> List.flatten() |> Enum.join() |> String.trim()
        %{filter | args: args}
    end)
  end

  def build_chain(filters), do: {:chain, filters}
  def build_setting([value]), do: {:setting, "sws_flags", String.trim(value)}
end
