defmodule FFix.Command.Build do
  @moduledoc false

  alias FFix.Command
  alias FFix.Command.Input
  alias FFix.Command.Mapping
  alias FFix.Command.Output
  alias FFix.Graph.Builder
  alias FFix.Graph.Export
  alias FFix.Graph.StreamRef

  @command_keys [:global, :inputs, :terminals, :settings]

  @spec command(Output.t() | [Output.t()], keyword()) :: Command.t()
  def command(output_or_outputs, options \\ []) do
    validate_options!(options)
    outputs = normalize_outputs!(output_or_outputs)
    streams = mapped_streams!(outputs)

    candidate =
      Builder.graph(
        outputs: streams,
        terminals: Keyword.get(options, :terminals, []),
        settings: Keyword.get(options, :settings, [])
      )

    input_refs =
      candidate.order
      |> Enum.map(&Map.fetch!(candidate.nodes, &1))
      |> Enum.filter(&(&1.kind == :input))
      |> Enum.map(& &1.input_ref)

    captured_inputs =
      input_refs
      |> Enum.map(& &1.declaration)
      |> Enum.reject(&is_nil/1)
      |> unique_inputs!()

    inputs = resolve_inputs!(captured_inputs, input_refs, options)
    filters? = Enum.any?(candidate.nodes, fn {_id, node} -> node.kind == :filter end)

    {graph, outputs} =
      if filters? do
        {candidate, lower_outputs(outputs, candidate.exports)}
      else
        if candidate.settings != [] do
          raise ArgumentError,
                "graph settings require filter nodes; cannot discard settings from a direct mapping command"
        end

        {nil, direct_outputs(outputs)}
      end

    Command.new(
      global: Keyword.get(options, :global, []),
      inputs: inputs,
      graph: graph,
      outputs: outputs
    )
    |> Command.validate!()
  end

  defp validate_options!(options) do
    unless Keyword.keyword?(options) do
      raise ArgumentError, "command options must be a keyword list"
    end

    keys = Keyword.keys(options)

    if length(keys) != length(Enum.uniq(keys)) do
      raise ArgumentError, "duplicate command option"
    end

    unknown = keys -- @command_keys

    if unknown != [] do
      raise ArgumentError,
            "unknown command keys: #{inspect(unknown)}; pass output declarations as the first argument"
    end
  end

  defp normalize_outputs!(output_or_outputs) do
    outputs = List.wrap(output_or_outputs)

    if outputs == [] do
      raise ArgumentError, "command requires at least one output"
    end

    Enum.each(outputs, fn
      %Output{mappings: mappings} when is_list(mappings) -> :ok
      other -> raise ArgumentError, "expected an Output declaration, got: #{inspect(other)}"
    end)

    outputs
  end

  defp mapped_streams!(outputs) do
    Enum.flat_map(outputs, fn output ->
      Enum.map(output.mappings, fn
        %Mapping{source: %StreamRef{} = stream} ->
          stream

        %Mapping{source: %Export{}} ->
          raise ArgumentError,
                "bare graph Export sources are not supported by output-first commands; use graph[:name] for a captured stream, or Command.new/1 with an explicit graph"

        other ->
          raise ArgumentError,
                "expected a mapping with a StreamRef source, got: #{inspect(other)}"
      end)
    end)
  end

  defp resolve_inputs!(captured_inputs, input_refs, options) do
    case Keyword.fetch(options, :inputs) do
      :error ->
        if Enum.any?(input_refs, &is_nil(&1.declaration)) do
          raise ArgumentError,
                "unbound input reference; select streams from Input.new/2 declarations, bind graph inputs, or supply an explicit ordered :inputs list"
        end

        captured_inputs

      {:ok, explicit_inputs} ->
        inputs = unique_inputs!(explicit_inputs)
        declarations = Map.new(inputs, &{&1.id, &1})

        Enum.each(captured_inputs, fn captured ->
          case Map.fetch(declarations, captured.id) do
            {:ok, ^captured} ->
              :ok

            {:ok, _conflicting} ->
              raise ArgumentError,
                    "conflicting input snapshots for declaration #{inspect(captured.id)}"

            :error ->
              raise ArgumentError,
                    "captured input declaration #{inspect(captured.id)} is missing from explicit :inputs"
          end
        end)

        inputs
    end
  end

  defp unique_inputs!(inputs) do
    unless is_list(inputs) do
      raise ArgumentError, "command inputs must be an explicit ordered list of Input declarations"
    end

    {reversed, _seen} =
      Enum.reduce(inputs, {[], %{}}, fn input, {ordered, seen} ->
        unless is_struct(input, Input) do
          raise ArgumentError, "expected an Input declaration, got: #{inspect(input)}"
        end

        Command.validate_input!(input)

        case Map.fetch(seen, input.id) do
          {:ok, ^input} when input.id != nil ->
            {ordered, seen}

          {:ok, _conflicting} when input.id != nil ->
            raise ArgumentError,
                  "conflicting input snapshots for declaration #{inspect(input.id)}"

          _new ->
            {[input | ordered], Map.put(seen, input.id, input)}
        end
      end)

    Enum.reverse(reversed)
  end

  defp direct_outputs(outputs) do
    Enum.map(outputs, fn output ->
      mappings =
        Enum.map(output.mappings, fn mapping ->
          %{mapping | source: %{mapping.source | context: nil}}
        end)

      %{output | mappings: mappings}
    end)
  end

  defp lower_outputs(outputs, exports) do
    {outputs, _remaining} =
      Enum.map_reduce(outputs, exports, fn output, remaining ->
        {mappings, remaining} =
          Enum.map_reduce(output.mappings, remaining, fn mapping, [export | rest] ->
            {%{mapping | source: export}, rest}
          end)

        {%{output | mappings: mappings}, remaining}
      end)

    outputs
  end
end
