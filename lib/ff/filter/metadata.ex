defmodule FF.Filter.Metadata do
  @moduledoc false

  alias FF.Filter.Help
  alias FF.Parsers

  # Keep ffmpeg help scraping at compile time so the runtime builder only reads
  # normalized metadata instead of shelling out on each call.
  @filters Help.filters()
  @filter_specs (
                  parse_specs = fn lines ->
                    lines
                    |> Enum.map(&Parsers.FilterSpec.parse/1)
                    |> Enum.reduce(%{all: [], current: nil}, fn
                      [{:depth, depth}, name, {:type, type}, flags, desc], %{all: all, current: current}
                      when depth in [2, 3] ->
                        spec = %{name: name, type: type, flags: flags, desc: desc}
                        %{all: all ++ [current], current: spec}

                      [{:depth, 5}, enum, num, flags, desc], %{current: current} = acc ->
                        enum_spec = %{enum: enum, num: num, flags: flags, desc: desc}
                        %{acc | current: Map.update(current, :sub, [enum_spec], &(&1 ++ [enum_spec]))}
                    end)
                    |> then(fn %{all: all, current: current} -> all ++ [current] end)
                    |> Enum.filter(& &1)
                    |> Map.new(&{String.to_atom(&1.name), &1})
                  end

                  Map.new(@filters, fn {name, _filter} ->
                    {name, parse_specs.(Help.filter(name))}
                  end)
                )

  @spec filters() :: map()
  def filters, do: @filters

  @spec filter!(atom() | String.t()) :: map()
  def filter!(name) when is_binary(name), do: filter!(String.to_atom(name))

  def filter!(name) when is_atom(name) do
    case @filters[name] do
      nil -> raise ArgumentError, "unknown filter #{inspect(name)}"
      filter -> filter
    end
  end

  @spec filter_spec(atom() | String.t()) :: map()
  def filter_spec(name) when is_binary(name), do: filter_spec(String.to_atom(name))
  def filter_spec(name) when is_atom(name), do: Map.get(@filter_specs, name, %{})

  @spec build_options_doc(map()) :: String.t()
  def build_options_doc(options) do
    options
    |> Enum.map(fn {name, config} ->
      build_option_doc(name, config)
    end)
    |> Enum.join("\n")
  end

  @spec build_options_typespec(map()) :: Macro.t()
  def build_options_typespec(options) do
    quote do
      [unquote_splicing(for option <- options, do: option_typespec(option))]
    end
  end

  defp build_option_doc(name, config) do
    case config[:sub] do
      nil ->
        "  * #{name} - #{config.desc}"

      flags ->
        flags =
          flags
          |> Enum.map(fn flag ->
            num = if flag.num != "", do: " (#{flag.num}) ", else: ""
            desc = if flag.desc != "", do: " - #{flag.desc}", else: ""

            "    - #{flag.enum}#{num}#{desc}"
          end)
          |> Enum.join("\n")

        """
          * #{name} - #{config.desc}
        #{flags}
        """
    end
  end

  defp option_typespec({name, config}) do
    type =
      case config.type do
        {:array, type} ->
          quote(do: [unquote(core_type(type, config[:sub]))])

        type ->
          core_type(type, config[:sub])
      end

    quote do
      {unquote(name), unquote(type)}
    end
  end

  defp core_type(type, nil) do
    case type do
      :int -> quote(do: integer())
      :int64 -> quote(do: integer())
      :binary -> quote(do: binary())
      :boolean -> quote(do: boolean())
      :string -> quote(do: String.t())
      :float -> quote(do: float())
      :double -> quote(do: float())
      _ -> quote(do: term())
    end
  end

  defp core_type(type, sub) do
    case type do
      :int -> enum_typespec(sub)
      :flags -> quote(do: [unquote(enum_typespec(sub))])
      _ -> quote(do: term())
    end
  end

  defp enum_typespec([]), do: quote(do: term())

  defp enum_typespec(sub) do
    sub
    |> Enum.map(&String.to_atom(&1.enum))
    |> Enum.reduce(fn left, right -> {:|, [], [left, right]} end)
  end
end
