defmodule FF.Parsers.FilterGraphTest do
  use ExUnit.Case, async: true

  alias FF.Parsers.FilterGraph

  test "parses" do
    line =
      "sofalizer=sofa=/path/to/ClubFritz6.sofa:type=freq:radius=2:speakers=FL 45|FR 315|BL 135|BR 225:gain=28"

    assert [
             "sofalizer",
             [
               {"sofa", "/path/to/ClubFritz6.sofa"},
               {"type", "freq"},
               {"radius", "2"},
               {"speakers", ["FL 45", "FR 315", "BL 135", "BR 225"]},
               {"gain", "28"}
             ]
           ] ==
             FilterGraph.parse(line)
  end
end
