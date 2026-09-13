defmodule FFix.Metadata do
  @moduledoc false

  alias FFix.Filter.Schema

  @metadata_path Path.expand("../../priv/ffmpeg/metadata.exs", __DIR__)
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

  @component_metadata Map.take(recorded, [:components, :shared])

  @spec path() :: String.t()
  def path, do: @metadata_path

  @spec component_metadata() :: map()
  def component_metadata, do: @component_metadata

  @spec filters() :: map()
  def filters, do: @filters

  @spec filter_specs() :: map()
  def filter_specs, do: @filter_specs

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
end
