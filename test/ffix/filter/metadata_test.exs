defmodule FFix.Filter.MetadataTest do
  use ExUnit.Case, async: true

  alias FFix.Discovery.Parser
  alias FFix.Filter.Metadata
  alias FFix.Filter.Schema
  alias FFix.Value

  @fixtures Path.expand("../../fixtures/discovery/ffmpeg-7.1.5", __DIR__)

  test "filter_spec exposes parsed option metadata" do
    spec = Metadata.filter_spec("drawtext")

    assert %{text: %{type: :string}, x: %{type: :string}, y: %{type: :string}} = spec
  end

  test "timeline filters expose the implicit enable option" do
    spec = Metadata.filter_spec("drawtext")

    assert %{enable: %{type: :string, implicit: :timeline}} = spec
  end

  test "framesync filters expose common framesync options" do
    spec = Metadata.filter_spec("overlay")

    assert %{
             eof_action: %{type: :int},
             shortest: %{type: :boolean},
             repeatlast: %{type: :boolean},
             ts_sync_mode: %{type: :int}
           } = spec
  end

  test "real help selects primary and framesync owners without exposing child sections" do
    entries = [
      captured_entry("scale", "V", "V", "..C"),
      captured_entry("scale2ref", "VV", "VV", "..C"),
      captured_entry("aresample", "A", "A"),
      captured_entry("overlay", "VV", "V", "TSC")
    ]

    %{specs: specs, filters: filters} = Schema.normalize!(entries)
    assert specs.scale.w.owner == "scale"
    assert specs.scale.param0.declared_default == "DBL_MAX"
    assert specs.scale.eof_action.owner == "framesync"
    refute Map.has_key?(specs.scale, :sws_flags)
    assert specs.scale2ref.w.owner == "scale(2ref)"
    assert Map.keys(specs.aresample) == [:sample_rate]
    assert specs.overlay.repeatlast.owner == "framesync"
    assert specs.overlay.repeatlast.owners == ["overlay", "framesync"]

    assert [%{owner: "overlay"}, %{owner: "framesync"}] =
             specs.overlay.repeatlast.declarations

    assert specs.overlay.repeatlast.desc =~ "extend last frame"
    assert filters.scale.inputs == [:V]
    assert hd(entries).help.dynamic_pads.inputs =~ "dynamic"
    assert Enum.any?(hd(entries).help.option_sections, &(&1.name == "SWScaler"))
  end

  test "framesync is selected once and its duplicate declaration wins without merging types" do
    primary = option("count", :int, "2")
    secondary = option("count", :string, "\"later\"")

    sections = [
      %{name: "Different AVClass", options: [primary]},
      %{name: "AVDCT", options: [option("excluded", :int, "1")]},
      %{name: "framesync", options: [secondary]}
    ]

    %{specs: %{fixture: specs}} = Schema.normalize!([entry(sections)])
    assert Map.keys(specs) == [:count]
    assert specs.count.type == :string
    assert specs.count.default == nil
    assert specs.count.owners == ["Different AVClass", "framesync"]

    assert specs.count.declarations == [
             Map.put(primary, :owner, "Different AVClass"),
             Map.put(secondary, :owner, "framesync")
           ]

    %{specs: %{fixture: specs}} = Schema.normalize!([entry([List.last(sections)])])
    assert length(specs.count.declarations) == 1
  end

  test "integer inference uses only complete scalar declared defaults, never help prose" do
    cases = [
      {:int, "2", 2},
      {:int, "0", 0},
      {:int64, "-1", -1},
      {:int64, "+2", 2},
      {:int, nil, nil},
      {:int, "repeat", nil},
      {:int, "auto", nil},
      {:int64, "I64_MIN", nil},
      {:int, "\"2\"", nil},
      {:int, "2.0", nil},
      {:int, "2suffix", nil},
      {:int, "2 ", nil},
      {:boolean, "1", nil},
      {:unsigned, "2", nil},
      {:uint64, "2", nil},
      {{:array, :int}, "2", nil}
    ]

    for {type, declared, expected} <- cases do
      declaration = %{option("count", type, declared) | help: "prose (default 999)"}

      %{specs: %{fixture: %{count: spec}}} =
        Schema.normalize!([entry([%{name: "owner", options: [declaration]}])])

      assert spec.default == expected
      assert spec.declared_default == declared
      assert spec.desc == "prose (default 999)"
    end
  end

  test "catalog pad signatures coexist with help details, including optionless filters" do
    entries = [
      captured_entry("null", "V", "V"),
      captured_entry("nullsink", "V", "|"),
      captured_entry("testsrc", "|", "V"),
      captured_entry("avsynctest", "|", "AV", "..C"),
      captured_entry("split", "V", "N")
    ]

    normalized = Schema.normalize!(entries)
    assert normalized.filters.null.inputs == [:V]
    assert normalized.filters.nullsink.outputs == [:|]
    assert normalized.filters.testsrc.inputs == [:|]
    assert normalized.filters.avsynctest.outputs == [:A, :V]
    assert normalized.filters.split.outputs == [:N]
    assert normalized.specs.null == %{}
    assert normalized.specs.nullsink == %{}
    assert normalized.specs.split.outputs.default == 2
    assert normalized.specs.split.outputs.owner == "(a)split"
    assert normalized == Schema.normalize!(Enum.reverse(entries))
  end

  test "invalid identities, duplicate registrations and unsupported pads fail explicitly" do
    valid = entry([])

    assert_raise ArgumentError, ~r/duplicate filter registration/, fn ->
      Schema.normalize!([valid, valid])
    end

    for invalid <- [
          put_in(valid.help.names, ["other"]),
          put_in(valid.help.kind, :encoder),
          put_in(valid.registration.names, ["fixture", "alias"]),
          put_in(valid.registration.kind, :decoder)
        ] do
      assert_raise ArgumentError, ~r/identities must match/, fn ->
        Schema.normalize!([invalid])
      end
    end

    for direction <- [:inputs, :outputs] do
      for help <- [Map.delete(valid.help, direction), Map.put(valid.help, direction, nil)] do
        assert_raise ArgumentError, ~r/missing .* pad heading/, fn ->
          Schema.normalize!([%{valid | help: help}])
        end
      end

      assert_raise ArgumentError, ~r/help has no .* pads/, fn ->
        Schema.normalize!([%{valid | help: Map.put(valid.help, direction, [])}])
      end

      for signature <- ["", "X", "VN", "A|", "NN"] do
        registration = Map.put(valid.registration, direction, signature)

        assert_raise ArgumentError, ~r/unsupported catalog .* pads/, fn ->
          Schema.normalize!([%{valid | registration: registration}])
        end
      end
    end
  end

  test "arrays, constants and unknown option types preserve filter Value semantics" do
    %{specs: %{aformat: specs}} =
      Schema.normalize!([captured_entry("aformat", "A", "A")])

    assert map_size(specs) == 6
    assert specs.sample_rates.type == {:array, :int}
    refute Map.has_key?(specs.sample_rates, :sub)
    assert Value.normalize(["44100", 48000], specs.sample_rates) == [44100, 48000]
    assert Value.normalize("44100|48000", specs.sample_rates) == "44100|48000"
    assert Value.normalize([:fltp, :s16], specs.sample_fmts) == ["fltp", "s16"]
    assert Value.normalize([:stereo], specs.channel_layouts) == ["stereo"]

    declaration = %{
      option("flags", :flags, nil)
      | constants: [
          %{name: "multi word", value: nil, flags: "..FV.......", help: "literal"},
          %{name: "zero-value", value: "0", flags: "..FV.......", help: "zero"}
        ],
        ranges: [%{min: "0", max: "INT_MAX"}]
    }

    unknown = option("future", {:unknown, "future-type"}, nil)

    %{specs: %{fixture: specs}} =
      Schema.normalize!([entry([%{name: "owner", options: [declaration, unknown]}])])

    assert [%{num: "", enum: "multi word"}, %{num: "0", enum: "zero-value"}] =
             specs.flags.sub

    assert specs.flags.ranges == declaration.ranges
    assert specs.future.type == {:unknown, "future-type"}
    assert Value.normalize([], specs.flags) == ""
    assert Value.normalize([:center, :top], specs.flags) == "center+top"
    assert Value.normalize("3", specs.flags) == 3
    assert Value.normalize("C+T", specs.flags) == "C+T"
    expression = FFix.expr("between(t,1,2)")
    assert Value.normalize(expression, specs.flags) == expression
  end

  test "only catalog timeline support adds enable, without replacing explicit declarations" do
    declaration = option("enable", :int, "0")
    explicit = entry([%{name: "owner", options: [declaration]}])
    timeline = put_in(explicit.registration.flags, "TSC")

    %{specs: %{fixture: %{enable: spec}}, filters: %{fixture: filter}} =
      Schema.normalize!([timeline])

    assert spec.owner == "owner"
    assert spec.default == 0
    refute Map.has_key?(spec, :implicit)
    assert filter.flags == [:T, :S, :C]

    runtime_option = %{option("value", :string, nil) | flags: "..FV.....T."}
    runtime_only = entry([%{name: "owner", options: [runtime_option]}])
    %{specs: %{fixture: specs}} = Schema.normalize!([runtime_only])
    refute Map.has_key?(specs, :enable)

    implicit = put_in(entry([]).registration.flags, "T.Z")
    %{specs: %{fixture: specs}, filters: %{fixture: filter}} = Schema.normalize!([implicit])
    assert filter.flags == [:T]
    assert specs.enable.implicit == :timeline
    assert specs.enable.declarations == []
  end

  defp captured_entry(name, inputs, outputs, flags \\ "...") do
    text = File.read!(Path.join(@fixtures, "filter-#{name}.txt"))
    {:ok, help} = Parser.help(:filter, text)

    %{
      registration: %{
        kind: :filter,
        names: [name],
        inputs: inputs,
        outputs: outputs,
        flags: flags,
        description: help.description
      },
      help: help
    }
  end

  defp entry(sections) do
    %{
      registration: %{
        kind: :filter,
        names: ["fixture"],
        inputs: "V",
        outputs: "V",
        flags: "...",
        description: "Fixture"
      },
      help: %{
        kind: :filter,
        names: ["fixture"],
        inputs: [%{index: 0, name: "default", media_type: "video"}],
        outputs: [%{index: 0, name: "default", media_type: "video"}],
        option_sections: sections
      }
    }
  end

  defp option(name, type, declared_default) do
    %{
      name: name,
      type: type,
      declared_default: declared_default,
      flags: "..FV.......",
      help: "Fixture option",
      constants: [],
      ranges: []
    }
  end
end
