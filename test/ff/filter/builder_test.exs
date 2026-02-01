defmodule FF.Filter.BuilderTest do
  use ExUnit.Case, async: true

  alias FF.Filter

  test "generated wrappers reject unknown options" do
    video = FF.input(0, :video)

    assert_raise ArgumentError, "foo is not a valid option", fn ->
      Filter.scale(video, foo: 1)
    end
  end
end
