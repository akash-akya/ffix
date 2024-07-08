defmodule FF.FilterGraph do
  alias FF.Filter.Builder.Pad

  def to_filtergraph(graph) do
    %{ops: ops} = collect(graph, %{ops: Map.new(), name_counter: Map.new()})
    visited = MapSet.new()

    {graph, _} =
      Enum.reduce(ops, {[], visited}, fn {_id, op}, {graph, visited} ->
        validate_inputs!(op.inputs, visited)

        inputs_str = inputs_to_str(op.inputs, ops)
        outputs_str = outputs_to_str(op.outputs, op.seq_id)
        options_str = options_to_str(op.options, op.spec)

        str = inputs_str <> to_string(op.name) <> options_str <> outputs_str <> ";"

        graph = graph ++ [str]
        visited = MapSet.put(visited, op.id)

        {graph, visited}
      end)

    Enum.join(graph, "\n")
  end

  defp validate_inputs!(inputs, visited) do
    Enum.each(inputs, fn input ->
      unless input.op == nil || MapSet.member?(visited, input.op_id) do
        raise "Unknown input, #{inspect(input.op)}"
      end
    end)
  end

  defp inputs_to_str(inputs, graph) do
    Enum.map(inputs, fn input ->
      if input.op == nil do
        "[stream_#{input.seq}]"
      else
        seq_id = Map.fetch!(graph, input.op_id).seq_id
        "[#{seq_id}_#{input.seq}]"
      end
    end)
    |> Enum.join("")
  end

  defp outputs_to_str(outputs, seq_id) do
    outputs
    |> Enum.with_index()
    |> Enum.map(fn {_output, seq} ->
      "[#{seq_id}_#{seq}]"
    end)
    |> Enum.join("")
  end

  defp options_to_str(options, _specs) do
    str =
      options
      |> Enum.map(fn {key, value} ->
        "#{key}=#{value}"
      end)
      |> Enum.join(":")

    if str != "" do
      "=" <> str
    else
      str
    end
  end

  defp collect(%Pad{op: nil} = _pad, acc), do: acc

  defp collect(%Pad{op: op}, acc) do
    acc =
      Enum.reduce(op.inputs, acc, fn input, acc ->
        collect(input, acc)
      end)

    inputs =
      Enum.map(op.inputs, fn input ->
        op_id = input.op && input.op.id
        Map.put(input, :op_id, op_id)
      end)

    if acc.ops[op.id] do
      acc
    else
      name_counter = Map.update(acc.name_counter, op.name, 0, &(&1 + 1))
      seq_id = gen_id(op.name, name_counter[op.name])
      ops = Map.put(acc.ops, op.id, Map.merge(op, %{inputs: inputs, seq_id: seq_id}))

      %{ops: ops, name_counter: name_counter}
    end
  end

  defp gen_id(name, 0), do: "#{name}"
  defp gen_id(name, count), do: "#{name}_#{count}"
end
