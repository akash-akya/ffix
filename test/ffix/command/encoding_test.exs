defmodule FFix.Command.EncodingTest do
  use ExUnit.Case, async: true

  alias FFix.Command.Encoding
  alias FFix.Encoder

  test "singletons retain absolute indexes including unconfigured and unknown media" do
    encoder = %Encoder{options: [threads: 2]}

    sources = [
      source(:audio, true, nil),
      source(:unknown, true, encoder),
      source(:video, true, :copy),
      source(:video, true, encoder)
    ]

    assert Encoding.plan!(sources) == [{encoder, "1"}, {:copy, "2"}, {encoder, "3"}]

    assert Encoding.plan!(Enum.reverse(sources)) == [
             {encoder, "0"},
             {:copy, "1"},
             {encoder, "2"}
           ]
  end

  test "identical singleton policies never collapse to broader scopes" do
    Enum.each([:copy, %Encoder{name: "aac"}], fn encoding ->
      sources = [source(:audio, true, encoding), source(:audio, true, encoding)]
      assert Encoding.plan!(sources) == [{encoding, "0"}, {encoding, "1"}]
    end)
  end

  test "unconfigured layouts emit no options, regardless of media or cardinality" do
    assert Encoding.plan!([source(:unknown, true, nil)]) == []
    assert Encoding.plan!([source(:unknown, false, nil)]) == []

    assert Encoding.plan!([
             source(:unknown, false, nil),
             source(:video, true, nil),
             source(:audio, false, nil)
           ]) == []
  end

  test "all-copy plural layouts use output-wide copy even with unknown media" do
    assert Encoding.plan!([source(:unknown, false, :copy)]) == [{:copy, nil}]

    assert Encoding.plan!([
             source(:audio, true, :copy),
             source(:unknown, false, :copy),
             source(:video, false, :copy)
           ]) == [{:copy, nil}]
  end

  test "plural groups preserve the order of first media occurrence" do
    encoder = %Encoder{name: "libx264", options: [crf: 18]}

    sources = [
      source(:audio, false, :copy),
      source(:video, false, encoder),
      source(:audio, true, :copy),
      source(:video, true, encoder),
      source(:subtitle, false, nil)
    ]

    assert Encoding.plan!(sources) == [{:copy, "a"}, {encoder, "v"}]
    assert Encoding.plan!(Enum.reverse(sources)) == [{encoder, "v"}, {:copy, "a"}]
  end

  test "all supported media have output scope prefixes" do
    encoder = %Encoder{options: [threads: 1]}

    sources = [
      source(:attachment, false, encoder),
      source(:data, false, encoder),
      source(:subtitle, false, encoder),
      source(:audio, false, encoder),
      source(:video, false, encoder)
    ]

    assert Encoding.plan!(sources) == [
             {encoder, "t"},
             {encoder, "d"},
             {encoder, "s"},
             {encoder, "a"},
             {encoder, "v"}
           ]
  end

  test "distinct encodings in singleton-only media groups use relative indexes" do
    encoder = %Encoder{name: "libx264", options: [crf: 18]}
    second_encoder = %{encoder | options: [crf: 28]}

    sources = [
      source(:video, true, nil),
      source(:audio, false, :copy),
      source(:video, true, encoder),
      source(:subtitle, true, :copy),
      source(:video, true, second_encoder),
      source(:subtitle, true, nil),
      source(:video, true, :copy)
    ]

    assert Encoding.plan!(sources) == [
             {encoder, "v:1"},
             {second_encoder, "v:2"},
             {:copy, "v:3"},
             {:copy, "a"},
             {:copy, "s:0"}
           ]

    assert Encoding.plan!(Enum.reverse(sources)) == [
             {:copy, "v:0"},
             {second_encoder, "v:1"},
             {encoder, "v:2"},
             {:copy, "s:1"},
             {:copy, "a"}
           ]
  end

  test "copying one media group never copies an unconfigured group" do
    assert Encoding.plan!([
             source(:audio, false, :copy),
             source(:video, false, nil)
           ]) == [{:copy, "a"}]
  end

  test "mixed copy and nil in an unknown-count media group are ambiguous" do
    for single <- [true, false], encodings <- [[:copy, nil], [nil, :copy]] do
      [first_encoding, second_encoding] = encodings

      assert_raise ArgumentError, ~r/ambiguous.*audio.*explicit single-stream mappings/, fn ->
        Encoding.plan!([
          source(:audio, false, first_encoding),
          source(:audio, single, second_encoding)
        ])
      end
    end
  end

  test "different encoder names, options, or policies in a plural group are ambiguous" do
    encoder = %Encoder{name: "libx264", options: [crf: 18]}

    for other <- [
          %Encoder{name: "libx265", options: [crf: 18]},
          %Encoder{name: "libx264", options: [crf: 28]},
          %Encoder{name: "libx264", options: [crf: 18.0]},
          :copy,
          nil
        ],
        single <- [true, false] do
      assert_raise ArgumentError, ~r/ambiguous.*video.*identical encoding/, fn ->
        Encoding.plan!([source(:video, false, encoder), source(:video, single, other)])
      end
    end
  end

  test "unknown media cannot be scoped in a configured plural layout" do
    encoder = %Encoder{name: "libx264"}

    for encoding <- [nil, :copy, encoder], single <- [true, false] do
      assert_raise ArgumentError, ~r/ambiguous.*unknown media.*typed media selections/, fn ->
        Encoding.plan!([
          source(:video, false, encoder),
          source(:unknown, single, encoding)
        ])
      end
    end

    assert_raise ArgumentError, ~r/unknown media/, fn ->
      Encoding.plan!([source(:unknown, false, encoder)])
    end
  end

  test "unknown media cannot mix copy and unconfigured policies" do
    for single <- [true, false] do
      assert_raise ArgumentError, ~r/unknown media/, fn ->
        Encoding.plan!([source(:unknown, false, :copy), source(:unknown, single, nil)])
      end
    end
  end

  defp source(media, single, encoding) do
    %{media: media, single: single, encoding: encoding}
  end
end
