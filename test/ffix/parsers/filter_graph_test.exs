defmodule FFix.Parsers.FilterGraphTest do
  use ExUnit.Case, async: true

  alias FFix.Parsers.FilterGraph

  test "parses settings, labels, instances, and raw args" do
    graph =
      "sws_flags=accurate_rnd+full_chroma_int; [0:v] drawtext@main = text='hello, world':x=20:y=20 [video]"

    assert [
             {:setting, "sws_flags", "accurate_rnd+full_chroma_int"},
             {:chain,
              [
                %{
                  inputs: ["0:v"],
                  name: "drawtext",
                  instance: "main",
                  args: "text=hello, world:x=20:y=20",
                  outputs: ["video"]
                }
              ]}
           ] = FilterGraph.parse(graph)
  end

  test "decodes graph escaping before option escaping" do
    [{:chain, [filter]}] =
      FilterGraph.parse(~S([0:v]drawtext@main=text=it\\\'s\\:ok\\\\end\,\;\[\]:x=20[out]))

    assert filter.instance == "main"
    assert FilterGraph.parse_args(filter.args) == [{"text", "it's:ok\\end,;[]"}, {"x", "20"}]
  end

  test "keeps positional repetitions, named repetitions, expressions and raw pipes" do
    assert FilterGraph.parse_args(~S(in:0:30:alpha=1:alpha=0)) ==
             [{:pos, "in"}, {:pos, "0"}, {:pos, "30"}, {"alpha", "1"}, {"alpha", "0"}]

    assert FilterGraph.parse_args(~S"text=a|b:x=if(gt(w,320),320,w):a\=b") ==
             [{"text", "a|b"}, {"x", "if(gt(w,320),320,w)"}, {:pos, "a=b"}]
  end

  test "quotes concatenate and backslashes inside quotes stay literal" do
    assert FilterGraph.parse_args(~S(text=one' two\three 'four)) ==
             [{"text", "one two\\three four"}]

    assert FilterGraph.parse_args(~S(text='it'\''s:ok')) == [{"text", "it's:ok"}]
  end

  test "trims only unprotected FFmpeg whitespace" do
    assert FilterGraph.parse_args("  text=  hello  :x=  20 \t") ==
             [{"text", "hello"}, {"x", "20"}]

    assert FilterGraph.parse_args(~S(text=\ hello\ :other=' world ')) ==
             [{"text", " hello "}, {"other", " world "}]

    assert FilterGraph.parse_args("text=\u00a0hello\u00a0") ==
             [{"text", "\u00a0hello\u00a0"}]

    [{:chain, [filter]}] = FilterGraph.parse(~S(drawtext=text=\\\ hello\\\ [out]))
    assert FilterGraph.parse_args(filter.args) == [{"text", " hello "}]
  end

  test "preserves empty values and FFmpeg token end behavior" do
    assert FilterGraph.parse_args("text=:x='':y=") == [{"text", ""}, {"x", ""}, {"y", ""}]
    assert FilterGraph.parse_args("text=tail\\") == [{"text", "tail\\"}]
    assert FilterGraph.parse_args("text='unterminated") == [{"text", "unterminated"}]
  end

  test "decodes label tokens and settings without interpreting filter-specific syntax" do
    assert [{:chain, [%{inputs: ["0:v"], outputs: ["a]b"]}]}] =
             FilterGraph.parse(~S([ 0:v ]null['a]b']))

    assert [{:setting, "sws_flags", "accurate_rnd+full_chroma_int"}] =
             FilterGraph.parse("sws_flags='accurate_rnd+full_chroma_int';")
  end

  test "rejects NUL and unescaped closing delimiters" do
    for source <- ["drawtext=text=a\0b", "[a\0b]null", "sws_flags=a\0b"] do
      assert_raise ArgumentError, ~r/NUL/, fn -> FilterGraph.parse(source) end
    end

    assert_raise ArgumentError, ~r/NUL/, fn -> FilterGraph.parse_args("text=a\0b") end
    assert_raise ArgumentError, fn -> FilterGraph.parse("drawtext=text=a]b") end

    assert_raise ArgumentError, ~r/labels must not be empty/, fn ->
      FilterGraph.parse("null[]")
    end
  end

  test "parses comma-separated chains with unlabeled filters" do
    graph = "testsrc,split[L1],hflip[L2];[L1][L2]hstack"

    assert [
             {:chain,
              [
                %{name: "testsrc", inputs: [], outputs: [], args: nil, instance: nil},
                %{name: "split", inputs: [], outputs: ["L1"], args: nil, instance: nil},
                %{name: "hflip", inputs: [], outputs: ["L2"], args: nil, instance: nil}
              ]},
             {:chain,
              [
                %{name: "hstack", inputs: ["L1", "L2"], outputs: [], args: nil, instance: nil}
              ]}
           ] = FilterGraph.parse(graph)
  end
end
