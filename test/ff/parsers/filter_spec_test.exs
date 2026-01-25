defmodule FF.Parsers.FilterSpecTest do
  use ExUnit.Case, async: true

  alias FF.Parsers.FilterSpec

  test "parses spec line" do
    line =
      " split             <string>     ..F.A...... set split frequencies (default \"500\")"

    assert [
             {:depth, 1},
             "split",
             {:type, :string},
             "..F.A......",
             "set split frequencies (default \"500\")"
           ] ==
             FilterSpec.parse(line)
  end

  test "parses enum values" do
    line =
      "     repeat          0            ..FV....... Repeat the previous frame."

    assert [
             {:depth, 5},
             "repeat",
             "0",
             "..FV.......",
             "Repeat the previous frame."
           ] ==
             FilterSpec.parse(line)
  end
end
