defmodule FFix.Filter.MetadataTest do
  use ExUnit.Case, async: true

  alias FFix.Filter.Metadata

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
end
