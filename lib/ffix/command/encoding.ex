defmodule FFix.Command.Encoding do
  @moduledoc false

  alias FFix.Encoder
  alias FFix.Graph.InputRef

  @type source :: %{
          media: InputRef.media() | :unknown,
          single: boolean(),
          encoding: nil | :copy | Encoder.t()
        }

  @typedoc "A `nil` specifier applies to all output streams."
  @type plan :: [{:copy | Encoder.t(), String.t() | nil}]

  @spec plan!([source()]) :: plan()
  def plan!(sources) do
    cond do
      Enum.all?(sources, & &1.single) ->
        indexed_plan(sources, nil)

      Enum.all?(sources, &is_nil(&1.encoding)) ->
        []

      Enum.all?(sources, &(&1.encoding == :copy)) ->
        [{:copy, nil}]

      true ->
        if Enum.any?(sources, &(&1.media == :unknown)) do
          raise ArgumentError,
                "ambiguous output encoding with unknown media; use typed media selections or explicit single-stream mappings, or leave every mapping unconfigured or copy every mapping"
        end

        groups = Enum.group_by(sources, & &1.media)
        media_order = sources |> Enum.map(& &1.media) |> Enum.uniq()

        Enum.flat_map(media_order, fn media ->
          group_plan!(Map.fetch!(groups, media), media)
        end)
    end
  end

  defp group_plan!([first | _rest] = sources, media) do
    prefix = InputRef.media_prefix(media)

    cond do
      Enum.all?(sources, &(&1.encoding === first.encoding)) ->
        case first.encoding do
          nil -> []
          encoding -> [{encoding, prefix}]
        end

      Enum.all?(sources, & &1.single) ->
        indexed_plan(sources, prefix)

      true ->
        raise ArgumentError,
              "ambiguous output encoding for #{media} selections with unknown stream counts; use identical encoding for every #{media} mapping or explicit single-stream mappings"
    end
  end

  defp indexed_plan(sources, prefix) do
    sources
    |> Enum.with_index()
    |> Enum.flat_map(fn {source, index} ->
      suffix =
        case prefix do
          nil -> Integer.to_string(index)
          media -> "#{media}:#{index}"
        end

      case source.encoding do
        nil -> []
        encoding -> [{encoding, suffix}]
      end
    end)
  end
end
