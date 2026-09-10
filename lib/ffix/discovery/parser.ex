defmodule FFix.Discovery.Parser do
  @moduledoc """
  Pure parsers for FFmpeg metadata output. These functions never start FFmpeg.

  Results are `{:ok, metadata}` or `{:error, FFix.Discovery.Error.t()}`.
  Names and raw flags stay strings. Registries preserve alias groups; help
  preserves ordered option sections, properties, and notes. Property labels
  remain strings so unfamiliar fields are retained without creating atoms.

  Options include `name`, `type`, `flags`, `help`, `declared_default`, `ranges`,
  and ordered `constants`. Defaults, bounds, and constant values retain their
  printed spelling, including quotes. Unknown types are `{:unknown, name}`;
  array types are `{:array, type}`. These declarations are not full validation
  rules or effective runtime defaults.
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

  @doc "Parses version/build provenance, retaining the complete original text."
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
