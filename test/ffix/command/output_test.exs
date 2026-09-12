defmodule FFix.Command.OutputTest do
  use ExUnit.Case, async: true

  alias FFix.Command.{Mapping, Output}

  test "sources and names preserve order without media grouping or deduplication" do
    input = FFix.input("input.mp4")
    sound = FFix.audio(input, 0)
    picture = FFix.video(input, 0)
    output = Output.new([{:sound, sound}, picture, {:main, picture}], "out.mp4", t: 2)

    assert output.mappings == [
             %Mapping{source: sound, name: :sound},
             %Mapping{source: picture},
             %Mapping{source: picture, name: :main}
           ]

    assert output.target == "out.mp4"
    assert output.options == [t: 2]
  end

  test "normalizes single sources, mappings, and named bindings without mutating mappings" do
    source = FFix.input("input.mp4") |> FFix.video(0)
    mapping = FFix.stream_copy(source)

    assert Output.new(source, "out.mp4").mappings == [%Mapping{source: source}]
    assert Output.new(mapping, "out.mp4").mappings == [mapping]

    assert Output.new([first: mapping, second: mapping], "out.mp4").mappings == [
             %{mapping | name: :first},
             %{mapping | name: :second}
           ]

    assert Output.new({:main, mapping}, "out.mp4").mappings == [%{mapping | name: :main}]
    assert mapping.name == nil
  end

  test "requires at least one source" do
    for sources <- [[], nil] do
      assert_raise ArgumentError, "output requires at least one source", fn ->
        Output.new(sources, "out.mp4")
      end
    end
  end
end
