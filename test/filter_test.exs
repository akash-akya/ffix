defmodule FF.FilterTest do
  use ExUnit.Case, async: true

  alias FF.Filter
  alias FF.Filter.Builder
  alias FF.Filter.Builder.Pad
  alias FF.Filter.Builder.Operation

  test "filter operations" do
    a = Builder.source(0)
    b = Builder.source(1)

    crossover = Filter.acrossover(b)
    crossfade = Filter.acrossfade(a, crossover)

    assert %Pad{
             op: %Operation{
               inputs: [
                 %Pad{op: nil, seq: 0, type: :static},
                 %Pad{
                   op: %Operation{
                     inputs: [%Pad{op: nil, seq: 1, type: :static}],
                     name: :acrossover,
                     ref: _
                   },
                   seq: 0,
                   type: :dynamic
                 }
               ],
               name: :acrossfade,
               ref: _
             },
             seq: 0,
             type: :static
           } = crossfade
  end
end
