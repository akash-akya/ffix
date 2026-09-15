defmodule FFix.Command.Output do
  @moduledoc """
  Choose the streams, encoding, and destination for one output.

  Create outputs with `FFix.output/3`, `new/3`, or a `FFix.Muxer` helper. Pass
  them to `FFix.command/2` to assemble the invocation.

      source = FFix.input("interview.mp4")

      output =
        FFix.output(
          [FFix.video(source, 0), FFix.audio(source, 0)],
          "excerpt.mp4",
          t: 30
        )

  The source list determines mapping order. Bare streams use FFmpeg's default
  encoders; `FFix.Encoder` and `FFix.stream_copy/1` choose encoding explicitly.
  General output options, such as `t`, apply to this destination. See
  `FFix.Command.Mapping` for encoding several tracks and `FFix.Muxer` for
  container options.

  ## Named mappings and callbacks

  Some FFmpeg options refer to output-stream positions. Give mappings names
  and use an option callback to build those references from the final order.
  This is useful for an HLS master playlist with two video renditions sharing
  one audio rendition:

      alias FFix.{Encoder, Filter, Muxer}
      source = FFix.input("interview.mp4")
      [high, low] = source |> FFix.video(0) |> Filter.fps(fps: 24) |> Filter.split(outputs: 2)

      high = high |> Filter.scale(w: -2, h: 720) |> Encoder.libx264(b: "1800k", g: 48)
      low = low |> Filter.scale(w: -2, h: 360) |> Encoder.libx264(b: "600k", g: 48)
      sound = Encoder.aac(FFix.audio(source, 0), b: "128k")

      output =
        Muxer.hls([high: high, low: low, sound: sound], "hls/%v.m3u8",
          hls_time: 4,
          master_pl_name: "master.m3u8",
          var_stream_map: fn streams ->
            Enum.join([
              "\#{streams.high.specifier},agroup:audio,name:720p",
              "\#{streams.low.specifier},agroup:audio,name:360p",
              "\#{streams.sound.specifier},agroup:audio,name:audio,default:yes"
            ], " ")
          end
        )

      FFix.command(output)

  Create the `hls` directory before executing. The callback receives:

      %{
        high: %{index: 0, specifier: "v:0"},
        low: %{index: 1, specifier: "v:1"},
        sound: %{index: 2, specifier: "a:0"}
      }

  `index` counts every output stream. `specifier` counts within its media type.
  Reordering the mappings updates these values automatically. Counts restart
  for each output, and names must be unique atoms within that output. Unnamed
  mappings count toward positions but have no entry in the callback map.

  Callbacks are accepted as encoder, muxer, and general output option values.
  Every mapping in that output must identify one required stream of known media
  so the positions can be calculated. Use indexed media selections or filter
  outputs rather than `:all`, optional selections, or raw queries.

  > #### Keep callbacks repeatable {: .tip}
  > Each option callback runs once per serialization. Inspecting a command and
  > then executing it calls the callbacks twice. Keep them free of side effects.

  Callback results undergo normal option-value checks. They must be values,
  rather than another callback. Missing names raise `KeyError`; exceptions from
  your callback propagate to the caller. Construction and `FFix.validate!/1`
  check the layout while leaving callbacks unevaluated.

  See the [HLS muxer reference](https://ffmpeg.org/ffmpeg-formats.html#hls-2)
  for playlist and rendition options.
  """

  alias FFix.Command
  alias FFix.Command.Mapping
  alias FFix.Encoder
  alias FFix.Muxer
  alias FFix.Options

  @type target :: String.t() | :stdout | {:pipe, non_neg_integer()} | {:url, String.t()}
  @type option :: {atom() | String.t(), term()}

  @type t :: %__MODULE__{
          target: target(),
          mappings: [Mapping.t()],
          muxer: FFix.Muxer.t() | nil,
          options: [option()]
        }

  defstruct [:target, :muxer, mappings: [], options: []]

  @doc """
  Declares an output from a source or ordered source list, a target, and options.

      FFix.Command.Output.new([main: video, sound: audio], "interview.mp4", t: 30)

  Sources may be stream references, selections, or configured mappings. For
  explicit low-level commands, graph export handles are also accepted; see
  `FFix.Command.new/1`.

  Targets can be path/URL strings, `{:url, url}`, `:stdout`, or `{:pipe, descriptor}`.
  The `muxer:` option accepts a `FFix.Muxer` configuration. Remaining options are
  general FFmpeg output controls; see `FFix.Command` for option syntax.
  """
  @spec new(Command.binding() | [Command.binding()], target(), [option()]) :: t()
  def new(sources, target, options \\ []) do
    Options.validate_endpoint!(target, :output)
    {configuration, raw_options} = Options.split!(options, [:muxer])
    Options.validate_cli!(raw_options, true)
    sources = List.wrap(sources)

    if sources == [] do
      raise ArgumentError, "output requires at least one source"
    end

    mappings =
      Enum.map(sources, fn
        {name, %Mapping{} = mapping} when is_atom(name) and name not in [nil, true, false] ->
          %{mapping | name: name}

        {name, source} when is_atom(name) and name not in [nil, true, false] ->
          %{Mapping.new(source) | name: name}

        %Mapping{} = mapping ->
          mapping

        source ->
          Mapping.new(source)
      end)

    %__MODULE__{
      target: target,
      mappings: mappings,
      muxer: Keyword.get(configuration, :muxer),
      options: raw_options
    }
  end

  @doc false
  def validate!(%__MODULE__{} = output) do
    Options.validate_endpoint!(output.target, :output)
    Options.validate_cli!(output.options, true)

    unless is_list(output.mappings) do
      raise ArgumentError, "output mappings must be a list of Mapping values"
    end

    if output.mappings == [] do
      raise ArgumentError, "output requires at least one source"
    end

    {encodings, _names} =
      Enum.map_reduce(output.mappings, MapSet.new(), fn
        %Mapping{name: name, encoding: encoding}, names ->
          unless is_atom(name) and name not in [true, false] do
            raise ArgumentError,
                  "output mapping name must be an atom or nil, got: #{inspect(name)}"
          end

          if name != nil and MapSet.member?(names, name) do
            raise ArgumentError, "duplicate output mapping name: #{inspect(name)}"
          end

          case encoding do
            unconfigured when unconfigured in [nil, :copy] -> :ok
            %Encoder{} -> Options.validate_component!(encoding)
            other -> raise ArgumentError, "invalid encoding configuration: #{inspect(other)}"
          end

          {encoding, MapSet.put(names, name)}

        other, _names ->
          raise ArgumentError, "invalid output mapping: #{inspect(other)}"
      end)

    if Enum.any?(encodings, &(&1 != nil)) do
      Options.reject_conflicts!(output.options, :encoding, encodings)
    end

    case output.muxer do
      nil ->
        :ok

      %Muxer{} = muxer ->
        Options.validate_component!(muxer)
        Options.reject_conflicts!(output.options, :muxer, [muxer])

      other ->
        raise ArgumentError, "invalid muxer configuration: #{inspect(other)}"
    end

    output
  end

  def validate!(other), do: raise(ArgumentError, "invalid command output: #{inspect(other)}")

  @doc false
  def callbacks?(%__MODULE__{} = output) do
    Options.callbacks?(output.options) or Options.callbacks?(output.muxer) or
      Enum.any?(output.mappings, &Options.callbacks?(&1.encoding))
  end
end
