defmodule FFix.Parsers.Lines do
  @moduledoc false

  alias FFix.Discovery.Error

  def read(text) do
    text
    |> String.split(["\r\n", "\n"])
    |> Enum.with_index(1)
    |> Enum.reject(fn {line, _number} -> String.trim(line) == "" end)
  end

  def parse!(parser, {text, number}) do
    case parser.(text) do
      {:ok, values, "", _context, _position, _offset} -> values
      _ -> invalid!("unrecognized metadata row", {text, number})
    end
  end

  def invalid!(message, {text, number} \\ {nil, nil}) do
    raise Error, reason: :invalid_output, message: message, line: number, text: text
  end

  def after_header(lines, headers) do
    headers = Enum.map(List.wrap(headers), &String.split/1)
    remaining = Enum.drop_while(lines, fn {line, _} -> String.split(line) not in headers end)

    case remaining do
      [_header | rows] -> rows
      [] -> invalid!("missing metadata header")
    end
  end

  def indented?(line) do
    case line do
      {<<space, _rest::binary>>, _number} when space in [?\s, ?\t] -> true
      _other -> false
    end
  end

  def blocks([]), do: []

  def blocks([heading | lines]) do
    {body, rest} = Enum.split_while(lines, &indented?/1)
    [[heading | body] | blocks(rest)]
  end
end
