defmodule FFix.Filter.Metadata do
  @moduledoc false

  alias FFix.Filter.Help
  alias FFix.Parsers

  @dynamic_count_options %{
    inputs: [:inputs, :nb_inputs, :n, :streams],
    outputs: [:outputs, :nb_outputs, :n, :streams]
  }
  @default_integer_regex ~r/\(default (-?\d+)\)/

  # Keep ffmpeg help scraping at compile time so the runtime builder only reads
  # normalized metadata instead of shelling out on each call.
  @filters Help.filters()
  @filter_names Map.new(@filters, fn {name, _filter} -> {Atom.to_string(name), name} end)
  @filter_specs (
                  option_default = fn
                    type, desc when type in [:int, :int64] ->
                      case Regex.run(@default_integer_regex, desc, capture: :all_but_first) do
                        [value] -> String.to_integer(value)
                        _ -> nil
                      end

                    _type, _desc ->
                      nil
                  end

                  build_option_spec = fn name, type, flags, desc ->
                    %{
                      name: name,
                      type: type,
                      flags: flags,
                      desc: desc,
                      default: option_default.(type, desc)
                    }
                  end

                  parse_specs = fn lines ->
                    lines
                    |> Enum.map(&Parsers.FilterSpec.parse/1)
                    |> Enum.reduce(%{all: [], current: nil}, fn
                      [{:depth, depth}, name, {:type, type}, flags, desc],
                      %{all: all, current: current}
                      when depth in [2, 3] ->
                        %{
                          all: all ++ [current],
                          current: build_option_spec.(name, type, flags, desc)
                        }

                      [{:depth, 5}, enum, num, flags, desc], %{current: current} = acc ->
                        enum_spec = %{enum: enum, num: num, flags: flags, desc: desc}

                        %{
                          acc
                          | current: Map.update(current, :sub, [enum_spec], &(&1 ++ [enum_spec]))
                        }
                    end)
                    |> then(fn %{all: all, current: current} -> all ++ [current] end)
                    |> Enum.filter(& &1)
                    |> Map.new(&{String.to_atom(&1.name), &1})
                  end

                  timeline_enable_spec = %{
                    name: "enable",
                    type: :string,
                    flags: [],
                    desc:
                      "timeline expression evaluated before each frame; the filter is enabled when non-zero",
                    default: nil,
                    implicit: :timeline
                  }

                  add_implicit_options = fn specs, filter ->
                    if :T in filter.flags do
                      Map.put_new(specs, :enable, timeline_enable_spec)
                    else
                      specs
                    end
                  end

                  Map.new(@filters, fn {name, filter} ->
                    specs = parse_specs.(Help.filter(name))
                    {name, add_implicit_options.(specs, filter)}
                  end)
                )

  @spec filters() :: map()
  def filters, do: @filters

  @spec filter_name!(atom() | String.t()) :: atom()
  def filter_name!(name) when is_atom(name) do
    case @filters[name] do
      nil -> raise ArgumentError, "unknown filter #{inspect(name)}"
      _filter -> name
    end
  end

  def filter_name!(name) when is_binary(name) do
    case @filter_names[name] do
      nil -> raise ArgumentError, "unknown filter #{inspect(name)}"
      filter_name -> filter_name
    end
  end

  @spec filter!(atom() | String.t()) :: map()
  def filter!(name), do: @filters[filter_name!(name)]

  @spec filter_spec(atom() | String.t()) :: map()
  def filter_spec(name), do: Map.get(@filter_specs, filter_name!(name), %{})

  @spec dynamic_count_option(map(), :inputs | :outputs) :: atom() | nil
  def dynamic_count_option(option_specs, kind) do
    @dynamic_count_options
    |> Map.fetch!(kind)
    |> Enum.find(&Map.has_key?(option_specs, &1))
  end

  @spec dynamic_count_from_options(map(), :inputs | :outputs, keyword()) :: integer() | nil
  def dynamic_count_from_options(option_specs, kind, options) when is_list(options) do
    case dynamic_count_option(option_specs, kind) do
      nil ->
        nil

      option ->
        parse_integer(Keyword.get(options, option)) || option_default(option_specs[option])
    end
  end

  @spec dynamic_count_from_args(map(), :inputs | :outputs, keyword()) :: integer() | nil
  def dynamic_count_from_args(option_specs, kind, args) when is_list(args) do
    case dynamic_count_option(option_specs, kind) do
      nil ->
        nil

      option ->
        option_name = Atom.to_string(option)

        args
        |> Enum.find_value(fn
          {^option_name, value} -> parse_integer(value)
          {_other, _value} -> nil
        end)
        |> Kernel.||(option_default(option_specs[option]))
    end
  end

  @spec option_default(map() | nil) :: integer() | nil
  def option_default(nil), do: nil
  def option_default(%{default: default}), do: default

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

  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp parse_integer(_value), do: nil

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

  defp core_type(type, _sub) do
    case type do
      :int -> quote(do: integer() | String.t() | atom())
      :flags -> quote(do: integer() | String.t() | atom() | [String.t() | atom()])
      _ -> quote(do: term())
    end
  end
end
