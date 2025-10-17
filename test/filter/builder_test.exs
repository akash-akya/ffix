defmodule FF.Filter.BuilderTest do
  use ExUnit.Case, async: true

  alias FF.Filter.Builder

  describe "filter_spec" do
    test "returns correct spec" do
      assert %{
               channels: %{
                 flags: "..F.A......",
                 name: "channels",
                 type: :int,
                 desc: "set channels (from 1 to 8) (default 1)"
               },
               orientation: %{
                 flags: "..FV.......",
                 name: "orientation",
                 type: :int,
                 sub: [
                   %{flags: "..FV.......", enum: "vertical", desc: "", num: "0"},
                   %{flags: "..FV.......", enum: "horizontal", desc: "", num: "1"}
                 ],
                 desc: "set orientation (from 0 to 1) (default vertical)"
               },
               overlap: %{
                 flags: "..F.A......",
                 name: "overlap",
                 type: :float,
                 desc: "set window overlap (from 0 to 1) (default 1)"
               },
               sample_rate: %{
                 flags: "..F.A......",
                 name: "sample_rate",
                 type: :int,
                 desc: "set sample rate (from 15 to INT_MAX) (default 44100)"
               },
               scale: %{
                 flags: "..FV.......",
                 name: "scale",
                 type: :int,
                 sub: [
                   %{flags: "..FV.......", enum: "lin", desc: "linear", num: "0"},
                   %{flags: "..FV.......", enum: "log", desc: "logarithmic", num: "1"}
                 ],
                 desc: "set input amplitude scale (from 0 to 1) (default log)"
               },
               slide: %{
                 flags: "..FV.......",
                 name: "slide",
                 type: :int,
                 sub: [
                   %{
                     flags: "..FV.......",
                     enum: "replace",
                     desc: "consume old columns with new",
                     num: "0"
                   },
                   %{
                     flags: "..FV.......",
                     enum: "scroll",
                     desc: "consume only most right column",
                     num: "1"
                   },
                   %{
                     flags: "..FV.......",
                     enum: "fullframe",
                     desc: "consume full frames",
                     num: "2"
                   },
                   %{
                     flags: "..FV.......",
                     enum: "rscroll",
                     desc: "consume only most left column",
                     num: "3"
                   }
                 ],
                 desc: "set input sliding mode (from 0 to 3) (default fullframe)"
               },
               win_func: %{
                 flags: "..F.A......",
                 name: "win_func",
                 type: :int,
                 sub: [
                   %{flags: "..F.A......", enum: "rect", desc: "Rectangular", num: "0"},
                   %{flags: "..F.A......", enum: "bartlett", desc: "Bartlett", num: "4"},
                   %{flags: "..F.A......", enum: "hann", desc: "Hann", num: "1"},
                   %{flags: "..F.A......", enum: "hanning", desc: "Hanning", num: "1"},
                   %{flags: "..F.A......", enum: "hamming", desc: "Hamming", num: "2"},
                   %{flags: "..F.A......", enum: "blackman", desc: "Blackman", num: "3"},
                   %{flags: "..F.A......", enum: "welch", desc: "Welch", num: "5"},
                   %{flags: "..F.A......", enum: "flattop", desc: "Flat-top", num: "6"},
                   %{flags: "..F.A......", enum: "bharris", desc: "Blackman-Harris", num: "7"},
                   %{flags: "..F.A......", enum: "bnuttall", desc: "Blackman-Nuttall", num: "8"},
                   %{flags: "..F.A......", enum: "bhann", desc: "Bartlett-Hann", num: "11"},
                   %{flags: "..F.A......", enum: "sine", desc: "Sine", num: "9"},
                   %{flags: "..F.A......", enum: "nuttall", desc: "Nuttall", num: "10"},
                   %{flags: "..F.A......", enum: "lanczos", desc: "Lanczos", num: "12"},
                   %{flags: "..F.A......", enum: "gauss", desc: "Gauss", num: "13"},
                   %{flags: "..F.A......", enum: "tukey", desc: "Tukey", num: "14"},
                   %{flags: "..F.A......", enum: "dolph", desc: "Dolph-Chebyshev", num: "15"},
                   %{flags: "..F.A......", enum: "cauchy", desc: "Cauchy", num: "16"},
                   %{flags: "..F.A......", enum: "parzen", desc: "Parzen", num: "17"},
                   %{flags: "..F.A......", enum: "poisson", desc: "Poisson", num: "18"},
                   %{flags: "..F.A......", enum: "bohman", desc: "Bohman", num: "19"},
                   %{flags: "..F.A......", enum: "kaiser", desc: "Kaiser", num: "20"}
                 ],
                 desc: "set window function (from 0 to 20) (default rect)"
               }
             } ==
               Builder.filter_spec("spectrumsynth")
    end

    test "validate all" do
      filters = FF.Filter.Help.filters()

      for {name, _} <- filters do
        assert Builder.filter_spec(name)
      end
    end

    test "drawtext" do
      result =
        Builder.filter_spec("drawtext")

      result
      |> dbg()
    end

    test "param with space" do
      assert _result = Builder.filter_spec("afireqsrc")
    end
  end

  describe "operation/4" do
    test "raises error on invalid options" do
      a = Builder.source(0)
      b = Builder.source(1)

      assert_raise RuntimeError, "foo is not a valid option", fn ->
        Builder.operation(:acrossfade, [a, b], [:V], foo: "something")
      end
    end
  end
end
