defmodule FFix.Filter.Metadata do
  @moduledoc false

  alias FFix.Filter.Schema

  @metadata_path Path.expand("../../../priv/ffmpeg/metadata.exs", __DIR__)
  @external_resource @metadata_path

  {recorded, []} = Code.eval_file(@metadata_path)

  entries =
    case Map.fetch(recorded, :filters) do
      {:ok, entries} ->
        entries

      :error ->
        raise ArgumentError,
              "recorded metadata is missing filters; refresh priv/ffmpeg/metadata.exs"
    end

  normalized = Schema.normalize!(entries)
  @filters normalized.filters
  @filter_specs normalized.specs
  @filter_names Map.new(@filters, fn {name, _filter} -> {Atom.to_string(name), name} end)

  @dynamic_count_options %{
    inputs: [:inputs, :nb_inputs, :n, :streams],
    outputs: [:outputs, :nb_outputs, :n, :streams]
  }

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
    filter_name = Enum.find_value(option_specs, fn {_option, spec} -> spec[:filter_name] end)

    case filter_name do
      nil ->
        nil

      name ->
        case FFix.Filter.Shape.resolve(name, kind, options) do
          {:ok, media} -> length(media)
          {:unresolved, _reason} -> nil
        end
    end
  end

  @spec dynamic_count_from_args(map(), :inputs | :outputs, keyword()) :: integer() | nil
  def dynamic_count_from_args(option_specs, kind, args) when is_list(args) do
    dynamic_count_from_options(option_specs, kind, args)
  end

  @spec option_default(map() | nil) :: integer() | nil
  def option_default(nil), do: nil
  def option_default(%{default: default}), do: default
end
