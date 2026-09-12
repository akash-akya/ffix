defmodule FFix.Command.Render do
  @moduledoc false

  alias FFix.Encoder
  alias FFix.Graph
  alias FFix.Graph.InputRef

  def to_argv(prepared) do
    {graph_args, labels} = render_graph(prepared.graph)

    ["ffmpeg"] ++
      options_to_argv(prepared.global_options) ++
      Enum.flat_map(prepared.inputs, &input_to_argv/1) ++
      graph_args ++ Enum.flat_map(prepared.outputs, &output_to_argv(&1, labels))
  end

  defp render_graph(nil), do: {[], %{}}

  defp render_graph(graph) do
    rendered = Graph.Render.render(graph)
    labels = Map.new(rendered.exports, &{&1.ref, &1.label})

    args =
      if rendered.graph == "" do
        []
      else
        ["-filter_complex", rendered.graph]
      end

    {args, labels}
  end

  defp input_to_argv(input) do
    decoders =
      input.decoders
      |> Enum.sort_by(fn {selector, _decoder} -> selector end)
      |> Enum.flat_map(fn {selector, decoder} ->
        component_to_argv(decoder, "c", InputRef.selector_string(selector))
      end)

    options_to_argv(input.options) ++
      component_to_argv(input.demuxer, "f", nil) ++
      decoders ++ ["-i", endpoint(input.source)]
  end

  defp output_to_argv(output, labels) do
    maps = Enum.flat_map(output.sources, &["-map", map_source(&1, labels)])

    encodings =
      Enum.flat_map(output.encodings, fn
        {:copy, nil} -> ["-c", "copy"]
        {:copy, selector} -> ["-c:#{selector}", "copy"]
        {%Encoder{} = encoder, selector} -> component_to_argv(encoder, "c", selector)
      end)

    maps ++
      encodings ++
      component_to_argv(output.muxer, "f", nil) ++
      options_to_argv(output.options) ++ [endpoint(output.target)]
  end

  defp map_source({:filter, ref}, labels), do: "[#{Map.fetch!(labels, ref)}]"

  defp map_source({:input, reference, optional?}, _labels) do
    suffix = InputRef.selector_string(reference.selector)

    source =
      if suffix == "" do
        to_string(reference.input)
      else
        "#{reference.input}:#{suffix}"
      end

    if optional? and not String.ends_with?(source, "?") do
      source <> "?"
    else
      source
    end
  end

  defp component_to_argv(nil, _control, _selector), do: []

  defp component_to_argv(component, control, selector) do
    suffix =
      if selector == nil do
        ""
      else
        ":#{selector}"
      end

    selection =
      if component.name == nil do
        []
      else
        ["-#{control}#{suffix}", component.name]
      end

    selection ++
      Enum.flat_map(component.options, fn {key, value} ->
        ["-#{key}#{suffix}", scalar(value)]
      end)
  end

  defp options_to_argv(options) do
    Enum.flat_map(options, fn
      {key, :flag} -> ["-#{key}"]
      {key, value} -> ["-#{key}", cli_value(value)]
    end)
  end

  defp cli_value(true), do: "1"
  defp cli_value(false), do: "0"
  defp cli_value(values) when is_list(values), do: Enum.map_join(values, "+", &cli_value/1)
  defp cli_value(value), do: scalar(value)

  defp scalar(value) when is_float(value), do: FFix.Value.float_to_string(value)
  defp scalar(value), do: to_string(value)

  defp endpoint(:stdin), do: "pipe:0"
  defp endpoint(:stdout), do: "pipe:1"
  defp endpoint({:pipe, descriptor}), do: "pipe:#{descriptor}"
  defp endpoint({:url, url}), do: url
  defp endpoint(path), do: path

  def shell_escape(""), do: "''"

  def shell_escape(argument) do
    if String.match?(argument, ~r|^[A-Za-z0-9_@%+=:,./-]+$|) do
      argument
    else
      "'" <> String.replace(argument, "'", ~S('"'"')) <> "'"
    end
  end
end
