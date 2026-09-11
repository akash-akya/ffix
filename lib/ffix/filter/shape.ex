defmodule FFix.Filter.Shape do
  @moduledoc false

  alias FFix.Filter.Metadata

  @type media :: :audio | :video
  @type result :: {:ok, [media()]} | {:unresolved, String.t()}

  @counted_outputs %{
    split: {:video, :outputs, [:outputs], %{}},
    asplit: {:audio, :outputs, [:outputs], %{}},
    select: {:video, :outputs, [:expr, :outputs], %{e: :expr, n: :outputs}},
    aselect: {:audio, :outputs, [:expr, :outputs], %{e: :expr, n: :outputs}}
  }
  @counted_inputs %{
    hstack: :video,
    vstack: :video,
    amix: :audio,
    amerge: :audio,
    streamselect: :video,
    astreamselect: :audio
  }
  @channel_layouts %{"mono" => ["FC"], "stereo" => ["FL", "FR"]}

  @doc """
  Resolves ordered pads from recorded fixed signatures or a small explicit policy.

  Accepts both helper keywords and parsed string-key arguments, in wire order.
  An unresolved result is not a singleton or a sink: callers must preserve that
  state until an explicit shape is supplied, or reject it at materialization.
  Input media is deliberately not used to guess dynamic output media.
  """
  @spec resolve(atom() | String.t(), :inputs | :outputs, list()) :: result()
  def resolve(name, direction, args \\ []) when direction in [:inputs, :outputs] do
    name = Metadata.filter_name!(name)
    filter = Metadata.filter!(name)
    pads = Map.fetch!(filter, direction)

    cond do
      Map.has_key?(filter.dynamic_pads, direction) ->
        {:unresolved, "#{name} has option-dependent #{direction} in addition to fixed pads"}

      pads == [:N] ->
        dynamic(name, direction, args)

      true ->
        media =
          Enum.flat_map(pads, fn
            :| -> []
            :A -> [:audio]
            :V -> [:video]
          end)

        {:ok, media}
    end
  end

  defp dynamic(name, direction, args) do
    cond do
      name == :concat ->
        with {:ok, options} <- effective_options(args, [:n, :v, :a], %{}),
             {:ok, video_count} <- count(name, :v, options),
             {:ok, audio_count} <- count(name, :a, options) do
          outputs = List.duplicate(:video, video_count) ++ List.duplicate(:audio, audio_count)

          case direction do
            :outputs ->
              {:ok, outputs}

            :inputs ->
              with {:ok, segments} <- count(name, :n, options) do
                {:ok, List.duplicate(outputs, segments) |> List.flatten()}
              end
          end
        end

      direction == :outputs and Map.has_key?(@counted_outputs, name) ->
        {media, option, positional, aliases} = Map.fetch!(@counted_outputs, name)

        with {:ok, options} <- effective_options(args, positional, aliases),
             {:ok, count} <- count(name, option, options) do
          {:ok, List.duplicate(media, count)}
        end

      direction == :inputs and Map.has_key?(@counted_inputs, name) ->
        with {:ok, options} <- effective_options(args, [:inputs], %{}),
             {:ok, count} <- count(name, :inputs, options) do
          {:ok, List.duplicate(Map.fetch!(@counted_inputs, name), count)}
        end

      direction == :outputs and name == :ebur128 ->
        with {:ok, options} <- effective_options(args, [:video], %{}) do
          case value(name, :video, options) do
            enabled when enabled in [true, 1, "1", "true", "yes", "on"] ->
              {:ok, [:video, :audio]}

            disabled when disabled in [false, 0, "0", "false", "no", "off"] ->
              {:ok, [:audio]}

            _other ->
              {:unresolved, "ebur128 video is not a supported boolean"}
          end
        end

      direction == :outputs and name == :channelsplit ->
        channelsplit(args)

      true ->
        {:unresolved, "#{name} has unsupported dynamic #{direction}"}
    end
  end

  defp channelsplit(args) do
    with {:ok, options} <- effective_options(args, [:channel_layout, :channels], %{}) do
      layout = value(:channelsplit, :channel_layout, options)
      channels = value(:channelsplit, :channels, options)

      case Map.fetch(@channel_layouts, layout) do
        {:ok, available} ->
          selected =
            case channels do
              "all" -> available
              channels when is_binary(channels) -> String.split(channels, "+")
              _other -> []
            end

          if selected != [] and Enum.uniq(selected) == selected and
               Enum.all?(selected, &(&1 in available)) do
            {:ok, List.duplicate(:audio, length(selected))}
          else
            {:unresolved, "channelsplit channels are not a supported selection"}
          end

        :error ->
          {:unresolved, "channelsplit channel layout is not supported by inference"}
      end
    end
  end

  # Only confirmed aliases and positional slots belong here. An option named `n`
  # is not evidence that it controls pad count on an arbitrary filter.
  defp effective_options(args, positional, aliases) do
    aliases =
      Map.new(aliases, fn {alias_name, name} -> {to_string(alias_name), to_string(name)} end)

    positional = Enum.map(positional, &to_string/1)

    result =
      Enum.reduce_while(args, {%{}, positional, false}, fn {key, value},
                                                           {options, slots, named?} ->
        case key do
          :pos ->
            case {slots, named?} do
              {[slot | remaining], false} ->
                {:cont, {Map.put(options, slot, value), remaining, false}}

              _other ->
                {:halt,
                 {:unresolved,
                  "unsupported positional option or positional value after named option"}}
            end

          key ->
            key = to_string(key)

            {key, value} =
              case key do
                "/" <> name -> {name, {:file, value}}
                name -> {name, value}
              end

            canonical = Map.get(aliases, key, key)
            {:cont, {Map.put(options, canonical, value), slots, true}}
        end
      end)

    case result do
      {options, _slots, _named?} -> {:ok, options}
      {:unresolved, _reason} = unresolved -> unresolved
    end
  end

  defp count(name, option, options) do
    value = value(name, option, options)

    parsed =
      case value do
        integer when is_integer(integer) -> {integer, ""}
        string when is_binary(string) -> Integer.parse(string)
        _other -> :error
      end

    case parsed do
      {integer, ""} when integer >= 0 ->
        {:ok, integer}

      _other ->
        {:unresolved, "#{name} #{option} is not a non-negative integer: #{inspect(value)}"}
    end
  end

  defp value(name, option, options) do
    case Map.fetch(options, Atom.to_string(option)) do
      {:ok, value} when is_atom(value) and value not in [nil, true, false] ->
        Atom.to_string(value)

      {:ok, value} ->
        value

      :error ->
        spec = Map.fetch!(Metadata.filter_spec(name), option)

        case spec.declared_default do
          value when is_binary(value) -> String.trim(value, "\"")
          value -> value
        end
    end
  end
end
