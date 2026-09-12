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
end
