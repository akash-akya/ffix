defmodule FF.FilterTest do
  use ExUnit.Case, async: true

  alias FF.Filter
  alias FF.Filter.Builder
  alias FF.Filter.Builder.Pad
  alias FF.Filter.Builder.Operation

  test "filter operations" do
    a = Builder.source("0:v")
    b = Builder.source("1:v")

    crossover = Filter.acrossover(b)
    crossfade = Filter.acrossfade(a, crossover)

    assert %Pad{
             op: %Operation{
               id: _,
               inputs: [
                 %Pad{op: "0:v", seq: 0, type: :source},
                 %Pad{
                   op: %Operation{
                     id: _,
                     inputs: [%Pad{op: "1:v", seq: 0, type: :source}],
                     name: :acrossover
                   },
                   seq: 0,
                   type: :dynamic
                 }
               ],
               name: :acrossfade
             },
             seq: 0,
             type: :static
           } = crossfade
  end

  test "accepts options" do
    a = Builder.source("0:v")
    b = Builder.source("1:v")

    crossover = Filter.acrossover(b)
    crossfade = Filter.acrossfade(a, crossover, nb_samples: "10", curve1: "20")

    assert %Pad{
             op: %Operation{
               id: _,
               inputs: [
                 %Pad{op: "0:v", seq: 0, type: :source},
                 %Pad{
                   op: %Operation{
                     id: _,
                     inputs: [%Pad{op: "1:v", seq: 0, type: :source}],
                     name: :acrossover,
                     options: []
                   },
                   seq: 0,
                   type: :dynamic
                 }
               ],
               options: [nb_samples: "10", curve1: "20"],
               name: :acrossfade
             },
             seq: 0,
             type: :static
           } = crossfade
  end
end
