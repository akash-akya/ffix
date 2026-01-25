defmodule FF.Parsers.FilterListTest do
  use ExUnit.Case, async: true

  alias FF.Parsers.FilterList

  test "parses" do
    line = " ... ebur128           A->N       EBU R128 scanner."

    assert [[], "ebur128", {[:A], [:N]}, "EBU R128 scanner."] ==
             FilterList.parse(line)
  end
end
