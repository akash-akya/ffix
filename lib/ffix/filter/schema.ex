defmodule FFix.Filter.Schema do
  @moduledoc false

  @doc """
  Adapts trusted recorded filter registrations and complete public help to the
  builder schema. Catalog signatures determine helper arities. Mixed fixed and
  dynamic help annotations are retained separately rather than replacing the
  catalog's fixed pads.

  The effective option declaration is primary-first, framesync-last. Each spec
  retains its selected owner and all selected owner-tagged declarations.
  """
  @spec normalize!([map()]) :: %{filters: map(), specs: map()}
  def normalize!(entries) when is_list(entries) do
    Enum.reduce(entries, %{filters: %{}, specs: %{}}, fn entry, metadata ->
      {name, registration, help} = validate_entry!(entry)
      filter_name = String.to_atom(name)

      if Map.has_key?(metadata.filters, filter_name) do
        raise ArgumentError, "duplicate filter registration: #{name}"
      end

      filter = %{
        flags: catalog_flags(registration.flags),
        inputs: catalog_pads!(registration.inputs, name, :inputs),
        outputs: catalog_pads!(registration.outputs, name, :outputs),
        dynamic_pads: Map.get(help, :dynamic_pads, %{}),
        desc: registration.description
      }

      specs =
        help.option_sections
        |> option_specs()
        |> add_timeline(filter.flags)

      %{
        filters: Map.put(metadata.filters, filter_name, filter),
        specs: Map.put(metadata.specs, filter_name, specs)
      }
    end)
  end

  def normalize!(_entries) do
    raise ArgumentError, "recorded filters must be a list of registration/help pairs"
  end

  defp validate_entry!(entry) do
    case entry do
      %{
        registration: %{kind: :filter, names: [name]} = registration,
        help: %{kind: :filter, names: [name]} = help
      }
      when is_binary(name) ->
        unless String.match?(name, ~r/\A[a-z][a-z0-9_]*\z/) do
          raise ArgumentError, "unsupported filter helper name: #{inspect(name)}"
        end

        Enum.each([:inputs, :outputs], fn direction ->
          signature = Map.fetch!(registration, direction)

          case Map.get(help, direction) do
            nil ->
              raise ArgumentError, "filter #{name} help is missing #{direction} pad heading"

            [] when signature != "|" ->
              raise ArgumentError,
                    "filter #{name} help has no #{direction} pads for catalog #{inspect(signature)}"

            pads when is_list(pads) ->
              :ok

            %{dynamic: description} when is_binary(description) ->
              :ok

            pads ->
              raise ArgumentError,
                    "filter #{name} has unsupported help #{direction} pads: #{inspect(pads)}"
          end
        end)

        {name, registration, help}

      _other ->
        raise ArgumentError,
              "recorded filter registration/help identities must match: #{inspect(entry)}"
    end
  end

  defp catalog_flags(flags) do
    flags
    |> String.graphemes()
    |> Enum.flat_map(fn flag ->
      case flag do
        "T" -> [:T]
        "S" -> [:S]
        "C" -> [:C]
        _other -> []
      end
    end)
  end

  defp catalog_pads!(signature, name, direction) do
    case signature do
      "|" ->
        [:|]

      "N" ->
        [:N]

      fixed when is_binary(fixed) ->
        unless String.match?(fixed, ~r/\A[AV]+\z/) do
          raise ArgumentError,
                "filter #{name} has unsupported catalog #{direction} pads: #{inspect(signature)}"
        end

        Enum.map(String.graphemes(fixed), fn
          "A" -> :A
          "V" -> :V
        end)

      _other ->
        raise ArgumentError,
              "filter #{name} has unsupported catalog #{direction} pads: #{inspect(signature)}"
    end
  end

  defp option_specs(sections) do
    primary = Enum.find(sections, &(&1.name not in ["framesync", "SWScaler"]))
    framesync = Enum.find(sections, &(&1.name == "framesync"))

    [primary, framesync]
    |> Enum.reject(&is_nil/1)
    |> Enum.flat_map(fn section ->
      Enum.map(section.options, &Map.put(&1, :owner, section.name))
    end)
    |> Enum.reduce(%{}, fn declaration, specs ->
      name = String.to_atom(declaration.name)
      previous = Map.get(specs, name)

      declarations =
        case previous do
          nil -> [declaration]
          spec -> spec.declarations ++ [declaration]
        end

      spec =
        declaration
        |> Map.put(:desc, declaration.help)
        |> Map.put(:owners, declarations |> Enum.map(& &1.owner) |> Enum.uniq())
        |> Map.put(:declarations, declarations)
        |> put_constants(declaration.constants)

      Map.put(specs, name, spec)
    end)
  end

  defp put_constants(spec, constants) do
    case constants do
      [] ->
        spec

      constants ->
        values =
          Enum.map(constants, fn constant ->
            %{
              enum: constant.name,
              num: constant.value || "",
              flags: constant.flags,
              desc: constant.help
            }
          end)

        Map.put(spec, :sub, values)
    end
  end

  defp add_timeline(specs, flags) do
    if :T in flags do
      Map.put_new(specs, :enable, %{
        name: "enable",
        type: :string,
        flags: [],
        desc:
          "timeline expression evaluated before each frame; the filter is enabled when non-zero",
        declared_default: nil,
        ranges: [],
        constants: [],
        implicit: :timeline,
        owners: [],
        declarations: []
      })
    else
      specs
    end
  end
end
