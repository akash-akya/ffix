defmodule FFix.Discovery.Parser do
  @moduledoc """
  Parse saved FFmpeg capability listings and help text.

  Use `FFix.Discovery` to query an executable. Use these parsers when you
  already have its output, for example from a saved deployment report:

      text = File.read!("encoder-help.txt")
      {:ok, details} = FFix.Discovery.Parser.help(:encoder, text)

  Functions return `{:ok, metadata}` or `{:error, error}`. Catalog entries keep
  alias groups in `names`. Component help keeps ordered option sections,
  properties, and notes. Names, flags, and property labels remain strings.

  ## Option records

  Options contain `name`, `type`, `flags`, `help`, `declared_default`, `ranges`,
  and ordered `constants`. Defaults, bounds, and constant values keep their
  printed spelling, including quotes. Unknown types use `{:unknown, name}`;
  array types use `{:array, type}`.

  These fields describe FFmpeg's help. They are useful for reference displays;
  actual accepted values can depend on other options and runtime conditions.
  """

  import NimbleParsec

  alias FFix.Discovery.Error
  alias FFix.Parsers.AVOptions
  alias FFix.Parsers.ComponentHelp
  alias FFix.Parsers.DiscoveryList
  alias FFix.Parsers.Lines

  version_header =
    ignore(string("ffmpeg version "))
    |> utf8_string([{:not, ?\s}], min: 1)
    |> ignore(utf8_string([], min: 0))
    |> eos()

  defparsecp(:version_header, version_header)

  @type result(value) :: {:ok, value} | {:error, Error.t()}

  @doc """
  Parses a catalog for a kind accepted by `FFix.Discovery.list/2`.
  For format entries, `device?` is `nil` when an older listing omits that flag.
  """
  @spec list(atom(), String.t()) :: result([map()])
  def list(kind, text) do
    {:ok, DiscoveryList.parse!(kind, text)}
  rescue
    error in Error -> {:error, error}
  end

  @doc """
  Parses help for one component, rejecting multi-implementation responses.

  Protocol help only identifies option classes, so its `names` list is empty.
  `FFix.Discovery.help/3` supplies protocol names from the registry instead.
  `properties` is an ordered list of `{label, value}` strings, not a merged map.
  Filter pads are ordered lists or `%{dynamic: description}`. Mixed fixed/dynamic
  declarations retain the fixed list and add `dynamic_pads` keyed by direction.
  """
  @spec help(atom(), String.t()) :: result(map())
  def help(kind, text) do
    {:ok, ComponentHelp.parse!(kind, text)}
  rescue
    error in Error -> {:error, error}
  end

  @doc "Parses the rows of one AVOptions section, without its heading."
  @spec options(String.t()) :: result([map()])
  def options(text) do
    {:ok, text |> Lines.read() |> AVOptions.parse_rows!()}
  rescue
    error in Error -> {:error, error}
  end

  @doc """
  Extracts AVCodecContext, AVFormatContext, AVIOContext, and URLContext sections
  from full help. They remain separate from private options.
  """
  @spec shared(String.t()) :: result([map()])
  def shared(text) do
    {:ok, ComponentHelp.shared!(text)}
  rescue
    error in Error -> {:error, error}
  end

  @doc "Parses `ffmpeg -version` output into version, configuration, and library fields, retaining the original text."
  @spec version(String.t()) :: result(map())
  def version(text) do
    {:ok, version_info(Lines.read(text), text)}
  rescue
    error in Error -> {:error, error}
  end

  defp version_info(lines, text) do
    case lines do
      [] ->
        Lines.invalid!("missing FFmpeg version header")

      [header | remaining_lines] ->
        [version] = Lines.parse!(&version_header/1, header)
        configuration = Enum.find_value(remaining_lines, &configuration/1)

        libraries =
          Enum.flat_map(remaining_lines, fn
            {"lib" <> _ = line, _number} ->
              [library_version(line)]

            _other ->
              []
          end)

        %{version: version, configuration: configuration, libraries: libraries, raw: text}
    end
  end

  defp configuration(line) do
    case line do
      {"configuration: " <> value, _number} -> value
      _other -> nil
    end
  end

  defp library_version(line) do
    [name | versions] = String.split(line)
    {name, Enum.join(versions, " ")}
  end
end
