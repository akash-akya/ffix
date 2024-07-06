defmodule FF.Filter.Builder do
  defmodule Pad do
    @type t :: map
    defstruct [:op, :seq, :type]

    def new(op, seq, type) when type in [:static, :dynamic] do
      %__MODULE__{op: op, seq: seq, type: type}
    end
  end

  defmodule Operation do
    defstruct [:inputs, :name, :ref]

    def new(name, inputs, outputs) do
      operation = %__MODULE__{ref: make_ref(), name: name, inputs: inputs}

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
  end

  alias FF.Parsers

  def source(seq) do
    Pad.new(nil, seq, :static)
  end

  def operation(name, inputs, num_outputs \\ 1) do
    Operation.new(name, inputs, num_outputs)
  end

  def filter_spec(name) do
    name
    |> FF.Runner.filter()
    |> Parsers.FilterSpec.parse_from_desc()
    |> collect(%{all: [], current: nil})
    |> Enum.filter(& &1)
  end

  @option_depth 3
  @enum_depth 5

  defp collect([], acc) do
    acc.all ++ [acc.current]
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
end
