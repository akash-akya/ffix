defmodule FFix.Filter do
  @moduledoc """
  Generated helpers for ffmpeg filters.

  Each function mirrors one filter reported by the local `ffmpeg` executable at
  compile time. Function names and option keys stay close to ffmpeg. Function
  arguments are `FFix.Graph.StreamRef` values; the final argument is a keyword list of
  ffmpeg filter options.

      video
      |> scale(w: 1280, h: -1)
      |> fps(fps: 30)

  Most filters return a single `FFix.Graph.StreamRef`. Multi-output filters return a tuple
  or list:

      [left, right] = split(video, outputs: 2)
      stacked = hstack([left, hflip(right)])

  Some ffmpeg filters have dynamic output shapes. Use `FFix.shape/2` when the
  generated metadata cannot infer the shape you need:

      [audio, video] =
        audio_in
        |> ebur128(video: true)
        |> FFix.shape([:audio, :video])

  Use `filter/4` to supply a filter name, explicit output media, and options
  without metadata lookup. Use `FFix.shape/2` when a named helper needs an
  explicit output shape.

  Timeline-capable filters accept ffmpeg's implicit `enable:` option. Filters
  backed by ffmpeg framesync also accept the common `eof_action:`, `shortest:`,
  `repeatlast:`, and `ts_sync_mode:` options.
  """
  @moduledoc groups: [
               "Generic filters",
               "Source filters",
               "Video filters",
               "Audio filters",
               "Audio/video filters",
               "Multi-stream filters",
               "Sink filters",
               "Other filters"
             ]

  alias FFix.Graph.Builder
  alias FFix.Graph.StreamRef
  alias FFix.Graph.Terminal
  alias FFix.Filter.Metadata

  @type option :: {atom() | String.t(), String.t() | atom() | number() | FFix.Graph.Expr.t()}

  @doc group: "Generic filters"
  @doc """
  Builds a filter from explicit inputs, a name, output media, and optional values.

      video |> FFix.Filter.filter("scale", [:video], w: 1280, h: -2)
      FFix.Filter.filter([background, foreground], "overlay", [:video], x: 10)
      FFix.Filter.filter([], "vendor_source", [:audio], frequency: 440)
      FFix.Filter.filter(video, "nullsink", [])

  Inputs are a stream reference or a flat ordered list. Use `[]` for source
  filters. Output media is an ordered list of `:video`, `:audio`, or `:unknown`.
  Zero outputs return a terminal, one returns a reference, and multiple outputs
  return a list. This shape is graph information, not an emitted FFmpeg option;
  the caller must ensure it agrees with the actual filter configuration.

  Names and options pass through without registry or option-schema lookup, even
  for known filters. No defaults, flags, or array delimiters are inferred. Use
  scalar values, `FFix.expr/1`, or strings for compound syntax. Repeated `:pos`
  pairs supply positional arguments. Values are escaped during serialization.

  Named helpers retain metadata checks and shape inference. `FFix.Graph.parse!/1`
  still requires known filters: serialized text does not preserve media shapes
  supplied to this function.
  """
  @spec filter(StreamRef.t() | [StreamRef.t()], atom() | String.t(), [FFix.output_media()], [
          option()
        ]) ::
          StreamRef.t() | [StreamRef.t()] | Terminal.t()
  def filter(inputs, name, output_media, options \\ []),
    do: Builder.filter(inputs, name, output_media, options)

  filter_group = fn inputs, outputs ->
    cond do
      inputs == [] ->
        "Source filters"

      outputs == [] ->
        "Sink filters"

      :N in inputs or :N in outputs ->
        "Multi-stream filters"

      :A in inputs or :A in outputs ->
        if :V in inputs or :V in outputs do
          "Audio/video filters"
        else
          "Audio filters"
        end

      :V in inputs or :V in outputs ->
        "Video filters"

      true ->
        "Other filters"
    end
  end

  Enum.each(Metadata.filters(), fn {name, %{inputs: inputs, outputs: outputs, desc: desc}} ->
    if name == :filter do
      raise ArgumentError, "filter helper name conflicts with the generic filter operation"
    end

    inputs = Enum.reject(inputs, &(&1 == :|))
    outputs = Enum.reject(outputs, &(&1 == :|))
    group = filter_group.(inputs, outputs)

    input_args =
      inputs
      |> Enum.with_index()
      |> Enum.map(fn {type, idx} ->
        case type do
          :V -> "video_#{idx}"
          :A -> "audio_#{idx}"
          :N -> "streams"
        end
        |> String.to_atom()
        |> Macro.var(__MODULE__)
      end)

    input_specs =
      Enum.map(inputs, fn
        :N -> quote(do: [FFix.Graph.StreamRef.t()])
        _ -> quote(do: FFix.Graph.StreamRef.t())
      end)

    output_specs =
      case outputs do
        [] ->
          quote(do: FFix.Graph.Terminal.t())

        [:N] ->
          quote(do: [FFix.Graph.StreamRef.t()])

        [_single] ->
          quote(do: FFix.Graph.StreamRef.t())

        many ->
          quote do
            {unquote_splicing(Enum.map(many, fn _ -> quote(do: FFix.Graph.StreamRef.t()) end))}
          end
      end

    option_specs = Metadata.filter_spec(name)
    options_doc = Metadata.build_options_doc(option_specs)
    options_typespec = Metadata.build_options_typespec(option_specs)

    @doc group: group
    @doc """
    #{desc}

    ## Options

    #{options_doc}
    """
    @spec unquote(name)(unquote_splicing(input_specs), unquote(options_typespec)) ::
            unquote(output_specs)
    def unquote(name)(unquote_splicing(input_args), options \\ []) do
      Builder.apply_filter(
        unquote(name),
        [unquote_splicing(input_args)],
        unquote(outputs),
        options,
        unquote(Macro.escape(option_specs))
      )
    end
  end)
end
