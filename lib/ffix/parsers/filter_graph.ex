defmodule FFix.Parsers.FilterGraph do
  @moduledoc false

  import NimbleParsec

  @name_chars [?a..?z, ?A..?Z, ?0..?9, ?_]
  @ws_chars [?\n, ?\r, ?\t, ?\s]

  whitespace = ascii_string(@ws_chars, min: 1)
  maybe_whitespace = ignore(optional(whitespace))

  # av_get_token removes escapes outside quotes; inside quotes, even a
  # backslash is literal. Protected whitespace must survive trailing trim.
  escaped_piece =
    ignore(string("\\"))
    |> utf8_string([], 1)
    |> unwrap_and_tag(:protected)

  quoted_piece =
    ignore(string("'"))
    |> utf8_string([{:not, ?'}], min: 0)
    |> ignore(optional(string("'")))
    |> unwrap_and_tag(:protected)

  label_char = utf8_string([{:not, ?]}, {:not, ?'}, {:not, ?\\}], 1)

  label =
    ignore(string("["))
    |> concat(maybe_whitespace)
    |> repeat(choice([quoted_piece, escaped_piece, label_char]))
    |> reduce({__MODULE__, :decode_label, []})
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

  arg_char = utf8_string([{:not, ?[}, {:not, ?]}, {:not, ?,}, {:not, ?;}, {:not, ?'}], 1)

  raw_args =
    repeat(choice([quoted_piece, escaped_piece, arg_char]))
    |> reduce({__MODULE__, :decode_token, []})

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

  setting_value_char = utf8_string([{:not, ?;}, {:not, ?'}], 1)

  setting_value =
    repeat(choice([quoted_piece, escaped_piece, setting_value_char]))
    |> reduce({__MODULE__, :decode_token, []})

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

  option_char = utf8_string([{:not, ?:}, {:not, ?'}], 1)

  option_value =
    maybe_whitespace
    |> repeat(choice([quoted_piece, escaped_piece, option_char]))
    |> reduce({__MODULE__, :decode_token, []})

  option_key =
    ascii_string(@name_chars ++ [?-, ?/], min: 1)
    |> concat(maybe_whitespace)
    |> ignore(string("="))

  option =
    maybe_whitespace
    |> optional(option_key)
    |> concat(option_value)
    |> reduce({__MODULE__, :build_option, []})

  options = option |> repeat(ignore(string(":")) |> concat(option))
  defparsec(:filter_options, options)
  defparsec(:setting_option, option_value)

  @spec parse(String.t()) :: [tuple()]
  def parse(source) when is_binary(source) do
    reject_nul!(source)
    source |> filter_graph() |> parsed!()
  end

  @doc "Decodes option syntax after the filtergraph escaping layer has been removed."
  @spec parse_args(String.t() | nil) :: [{String.t() | :pos, String.t()}]
  def parse_args(source) when source in [nil, ""], do: []

  def parse_args(source) when is_binary(source) do
    reject_nul!(source)
    source |> filter_options() |> parsed!()
  end

  defp parsed!(result) do
    case result do
      {:ok, parsed, "", %{}, _, _} ->
        parsed

      {:ok, _parsed, rest, %{}, _, _} ->
        raise ArgumentError, "unexpected trailing input: #{inspect(rest)}"

      {:error, message, rest, %{}, _, _} ->
        raise ArgumentError, "#{message} at #{inspect(rest)}"
    end
  end

  defp reject_nul!(source) do
    if String.contains?(source, <<0>>) do
      raise ArgumentError, "filtergraph values must not contain NUL"
    end
  end

  def decode_label(pieces) do
    case decode_token(pieces) do
      "" -> raise ArgumentError, "filtergraph labels must not be empty"
      label -> label
    end
  end

  def decode_token(pieces) do
    pieces
    |> Enum.reverse()
    |> Enum.drop_while(&(&1 in [" ", "\t", "\r", "\n"]))
    |> Enum.reverse()
    |> Enum.map(fn
      {:protected, value} -> value
      value -> value
    end)
    |> IO.iodata_to_binary()
  end

  def build_option([value]), do: {:pos, value}
  def build_option([key, value]), do: {key, value}

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
        %{filter | args: values |> List.flatten() |> Enum.join()}
    end)
  end

  def build_chain(filters), do: {:chain, filters}

  def build_setting([value]) do
    [decoded] = value |> setting_option() |> parsed!()
    {:setting, "sws_flags", decoded}
  end
end
