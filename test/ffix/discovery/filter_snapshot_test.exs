defmodule FFix.Discovery.FilterSnapshotTest do
  use ExUnit.Case, async: true

  alias FFix.Discovery.Parser

  @fixtures Path.expand("../../fixtures/discovery/ffmpeg-7.1.5", __DIR__)
  @metadata Path.expand("../../../priv/ffmpeg/metadata.exs", __DIR__)

  test "the snapshot preserves the full captured catalog and matching help for every filter" do
    {:ok, catalog} = Parser.list(:filter, File.read!(Path.join(@fixtures, "filters-full.txt")))
    {metadata, []} = Code.eval_file(@metadata)
    recorded = Enum.map(metadata.filters, & &1.registration)
    assert length(catalog) == 551
    assert Enum.sort_by(recorded, & &1.names) == Enum.sort_by(catalog, & &1.names)

    for %{registration: registration, help: help} <- metadata.filters do
      assert help.kind == :filter
      assert registration.names == help.names
      assert help.inputs != nil
      assert help.outputs != nil
    end

    scale = Enum.find(metadata.filters, &("scale" in &1.registration.names))
    assert scale.help.dynamic_pads.inputs == "dynamic (depending on the options)"
    assert Enum.map(scale.help.option_sections, & &1.name) == ["scale", "SWScaler", "framesync"]
  end

  test "representative help captures retain full sections, pad declarations, and aliases" do
    for name <- ~w(scale scale2ref aresample aformat fade null testsrc nullsink avsynctest) do
      path = Path.join(@fixtures, "filter-#{name}.txt")

      assert {:ok, %{kind: :filter, names: [^name]} = help} =
               Parser.help(:filter, File.read!(path))

      assert help.inputs != nil
      assert help.outputs != nil
    end
  end

  test "the public parsers cover legacy catalog, option, and constant rows" do
    assert {:ok, [%{names: ["ebur128"], inputs: "A", outputs: "N", flags: "..."}]} =
             Parser.list(:filter, "Filters:\n ... ebur128 A->N EBU R128 scanner.\n")

    assert {:ok, [option]} =
             Parser.options("""
               split             <string>     ..F.A...... set split frequencies (default "500")
                   repeat          0            ..FV....... Repeat the previous frame.
             """)

    assert option.name == "split"
    assert option.type == :string
    assert option.declared_default == ~s("500")
    assert [%{name: "repeat", value: "0", help: "Repeat the previous frame."}] = option.constants
  end
end
