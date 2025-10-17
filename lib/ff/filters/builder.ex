defmodule FF.Filter.Builder do
  defmodule Pad do
    @type t :: map
    defstruct [:op, :seq, :type]

    def new(op, seq, type) when type in [:static, :dynamic, :source] do
      %__MODULE__{op: op, seq: seq, type: type}
    end
  end

  defmodule Operation do
    @type t :: map
    defstruct [:id, :inputs, :outputs, :name, :spec, :options]

    def new(name, inputs, outputs, options, spec) do
      operation = %__MODULE__{
        id: generate_id(),
        name: name,
        inputs: inputs,
        outputs: outputs,
        spec: spec,
        options: options
      }

      case outputs do
        [] ->
          :ok

        [:N] ->
          Pad.new(operation, 0, :dynamic)

        [term] when term in [:A, :V] ->
          Pad.new(operation, 0, :static)

        outputs ->
          outputs
          |> Enum.with_index()
          |> Enum.map(fn {_, count} ->
            Pad.new(operation, count, :static)
          end)
          |> List.to_tuple()
      end
    end

    defp generate_id, do: make_ref()
  end

  alias FF.Parsers
  alias FF.Filter.Help

  def source(name) do
    Pad.new(name, 0, :source)
  end

  @spec operation(String.t(), [Pad.t()], [Pad.t()], keyword) :: Operation.t()
  def operation(name, inputs, outputs, options) do
    spec = FF.Filter.Builder.filter_spec(name)
    :ok = validate_options!(options, spec)
    Operation.new(name, inputs, outputs, options, spec)
  end

  def filter_spec(name) do
    name
    |> Help.filter()
    |> Enum.map(&Parsers.FilterSpec.parse/1)
    |> collect(%{all: [], current: nil})
    |> Enum.filter(& &1)
    |> Enum.map(&normalize_flags/1)
    |> Map.new(&{String.to_atom(&1.name), &1})
  end

  @spec build_options_doc(map) :: String.t()
  def build_options_doc(options) do
    options
    |> Enum.map(fn {name, config} ->
      build_option_doc(name, config)
    end)
    |> Enum.join("\n")
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

            "    - #{flag.enum} #{num}#{desc} "
          end)
          |> Enum.join("\n")

        """
          * #{name} - #{config.desc}
        #{flags}
        """
    end
  end

  @spec build_options_typespec(map) :: term
  def build_options_typespec(options) do
    quote do
      [unquote_splicing(for option <- options, do: option_typespec(option))]
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
      :int -> quote(do: integer)
      :int64 -> quote(do: integer)
      :binary -> quote(do: binary)
      :boolean -> quote(do: boolean)
      :string -> quote(do: String.t())
      :float -> quote(do: float)
      :double -> quote(do: float)
      term -> term
    end
  end

  defp core_type(type, sub) do
    case type do
      :int ->
        enum_typespec(sub)

      :flags ->
        dbg(sub)
        # TODO: `flags` are sometimes supports multiple options and
        # sometimes does not
        quote(do: [unquote(enum_typespec(sub))])
    end
  end

  defp enum_typespec(sub) do
    sub
    |> Enum.map(& &1.enum)
    |> Enum.map(&String.to_atom/1)
    |> Enum.reduce(&{:|, [], [&1, &2]})
  end

  @option_depth 3
  @enum_depth 5

  defp collect([], acc) do
    acc.all ++ [acc.current]
  end

  defp collect([[{:depth, 2} | rest] | specs], acc) do
    [name, {:type, type}, flags, desc] = rest
    spec = %{name: name, type: type, flags: flags, desc: desc}
    %{current: current, all: all} = acc

    collect(specs, %{current: spec, all: all ++ [current]})
  end

  defp collect([[{:depth, @option_depth} | rest] | specs], acc) do
    [name, {:type, type}, flags, desc] = rest
    spec = %{name: name, type: type, flags: flags, desc: desc}
    %{current: current, all: all} = acc

    collect(specs, %{current: spec, all: all ++ [current]})
  end

  defp collect([[{:depth, @enum_depth} | rest] | specs], acc) do
    [enum, num, flags, desc] = rest
    enum_spec = %{enum: enum, num: num, flags: flags, desc: desc}
    %{current: current, all: all} = acc
    current = Map.update(current, :sub, [enum_spec], &(&1 ++ [enum_spec]))

    collect(specs, %{current: current, all: all})
  end

  defp validate_options!(options, specs) do
    case validate_options(options, specs) do
      :ok ->
        :ok

      {:error, error} ->
        raise error
    end
  end

  defp validate_options(options, specs) when is_list(options) do
    Enum.reduce_while(options, :ok, fn {k, v}, _acc ->
      with {:ok, spec} <- fetch_spec(specs, k),
           :ok <- validate_option_type(k, v, spec.type) do
        {:cont, :ok}
      else
        {:error, _} = error ->
          {:halt, error}
      end
    end)
  end

  defp fetch_spec(specs, key) do
    if spec = specs[key] do
      {:ok, spec}
    else
      {:error, "#{key} is not a valid option"}
    end
  end

  defp validate_option_type(option, value, type) do
    # TODO: validate type, currently only accepts binary
    valid? = is_binary(value)

    if valid? do
      :ok
    else
      {:error, "#{value} for #{option} must be #{type}"}
    end
  end

  defp normalize_flags(arg) do
    arg
    # case arg[:sub] do
    #   nil ->
    #     arg

    #   sub ->
    #     flags =
    #       Enum.map(sub, fn sub ->
    #         sub
    #       end)
    # end
  end
end
