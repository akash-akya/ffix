defmodule FF.FilterGraphTest do
  use ExUnit.Case, async: true

  alias FF.Filter
  alias FF.Filter.Builder
  alias FF.FilterGraph

  describe "to_filtergraph" do
    test "generates" do
      a = Builder.source(0)
      b = Builder.source(1)

      crossover = Filter.acrossover(b)
      crossfade = Filter.acrossfade(a, crossover, nb_samples: "10", curve1: "20")
      crossfade2 = Filter.acrossfade(crossover, crossfade, nb_samples: "30")

      expected_graph =
        """
        [stream_1]acrossover[acrossover_0];
        [stream_0][acrossover_0]acrossfade=nb_samples=10:curve1=20[acrossfade_0];
        [acrossover_0][acrossfade_0]acrossfade=nb_samples=30[acrossfade_1_0];
        """
        |> String.trim()

      assert FilterGraph.to_filtergraph(crossfade2) == expected_graph
    end
  end
end
