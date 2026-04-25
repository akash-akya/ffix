defmodule FFix.Filter.MetadataTest do
  use ExUnit.Case, async: true

  alias FFix.Filter.Metadata

  test "filter_spec exposes parsed option metadata" do
    spec = Metadata.filter_spec("drawtext")

    assert %{text: %{type: :string}, x: %{type: :string}, y: %{type: :string}} = spec
  end
end
