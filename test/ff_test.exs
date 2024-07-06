defmodule FfTest do
  use ExUnit.Case
  doctest Ff

  test "greets the world" do
    assert Ff.hello() == :world
  end
end
