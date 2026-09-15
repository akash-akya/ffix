defmodule FFix.Filter.ShapeTest do
  use ExUnit.Case, async: true

  alias FFix.Filter.Shape

  test "count inference honors confirmed aliases, positional slots and last assignment" do
    for name <- [:select, :aselect] do
      media =
        case name do
          :select -> :video
          :aselect -> :audio
        end

      for options <- [
            [n: 2],
            [outputs: 2],
            [outputs: 3, n: 2],
            [n: 3, outputs: 2],
            [outputs: 3, outputs: 2],
            [pos: "1", pos: 2],
            [pos: "1", pos: 3, n: 2],
            [{"n", "3"}, {"outputs", "2"}]
          ] do
        assert Shape.resolve(name, :outputs, options) == {:ok, [media, media]}
      end
    end

    assert Shape.resolve(:split, :outputs, pos: 3) == {:ok, [:video, :video, :video]}
    assert Shape.resolve(:asplit, :outputs, pos: "3", outputs: 2) == {:ok, [:audio, :audio]}
    assert Shape.resolve(:split, :outputs) == {:ok, [:video, :video]}
  end

  test "zero is resolved but malformed or unsupported counts never use defaults" do
    assert Shape.resolve(:split, :outputs, outputs: 0) == {:ok, []}
    assert Shape.resolve(:select, :outputs, n: "0") == {:ok, []}

    for value <- [-1, "-1", "invalid", "2suffix", "2.0", 2.0, nil, true, "2+1"] do
      assert {:unresolved, reason} = Shape.resolve(:split, :outputs, outputs: value)
      assert reason =~ "non-negative integer"
    end

    assert Shape.resolve(:split, :outputs, outputs: "bad", outputs: 3) ==
             {:ok, [:video, :video, :video]}

    assert {:unresolved, _reason} = Shape.resolve(:split, :outputs, outputs: 3, outputs: "bad")
    assert {:unresolved, _reason} = Shape.resolve(:split, :outputs, outputs: 2, pos: 3)
  end

  test "concat preserves segment input order and video then audio output order" do
    options = [pos: 2, pos: 1, pos: 2]
    assert Shape.resolve(:concat, :outputs, options) == {:ok, [:video, :audio, :audio]}

    assert Shape.resolve(:concat, :inputs, options) ==
             {:ok, [:video, :audio, :audio, :video, :audio, :audio]}

    assert Shape.resolve(:concat, :outputs, v: 2, v: 0, a: 0) == {:ok, []}
    assert Shape.resolve(:concat, :outputs, [{"v", "0"}, {"a", "1"}]) == {:ok, [:audio]}
    assert {:unresolved, _reason} = Shape.resolve(:concat, :outputs, a: "bad")
    assert {:unresolved, _reason} = Shape.resolve(:concat, :inputs, n: -1)
  end

  test "ebur128 video is pad zero and audio is pad one" do
    assert Shape.resolve(:ebur128, :outputs) == {:ok, [:audio]}

    for value <- [true, 1, "1", "true", "yes", "on"] do
      assert Shape.resolve(:ebur128, :outputs, video: value) == {:ok, [:video, :audio]}
    end

    assert Shape.resolve(:ebur128, :outputs, pos: true) == {:ok, [:video, :audio]}
    assert Shape.resolve(:ebur128, :outputs, video: true, video: false) == {:ok, [:audio]}
    assert Shape.resolve(:ebur128, :outputs, [{"video", "true"}]) == {:ok, [:video, :audio]}
    assert {:unresolved, _reason} = Shape.resolve(:ebur128, :outputs, video: "maybe")
  end

  test "positional arguments unrelated to shape do not prevent inference" do
    assert Shape.resolve(:ebur128, :outputs, pos: 1, pos: "640x480") ==
             {:ok, [:video, :audio]}

    assert Shape.resolve(:ebur128, :outputs, pos: 1, pos: "640x480", video: false) ==
             {:ok, [:audio]}

    assert Shape.resolve(:hstack, :inputs, pos: 3, pos: true) ==
             {:ok, [:video, :video, :video]}

    assert {:unresolved, _reason} =
             Shape.resolve(:ebur128, :outputs, video: true, pos: "640x480")
  end

  test "channelsplit supports mono and stereo without guessing unfamiliar layouts" do
    assert Shape.resolve(:channelsplit, :outputs) == {:ok, [:audio, :audio]}
    assert Shape.resolve(:channelsplit, :outputs, channel_layout: :mono) == {:ok, [:audio]}
    assert Shape.resolve(:channelsplit, :outputs, channels: "FR") == {:ok, [:audio]}

    assert Shape.resolve(:channelsplit, :outputs, pos: "stereo", pos: "FL+FR") ==
             {:ok, [:audio, :audio]}

    for options <- [
          [channel_layout: "5.1"],
          [channel_layout: "unknown", channels: "FL"],
          [channels: "FC"],
          [channels: "FL+FL"],
          [channels: ""]
        ] do
      assert {:unresolved, _reason} = Shape.resolve(:channelsplit, :outputs, options)
    end
  end

  test "fixed sources, sinks and mixed-media signatures are authoritative" do
    assert Shape.resolve(:testsrc, :inputs) == {:ok, []}
    assert Shape.resolve(:testsrc, :outputs) == {:ok, [:video]}
    assert Shape.resolve(:anullsink, :outputs) == {:ok, []}
    assert Shape.resolve(:avsynctest, :outputs) == {:ok, [:audio, :video]}
    assert Shape.resolve(:scale2ref, :outputs) == {:ok, [:video, :video]}
    assert Shape.resolve(:scale, :outputs, w: "rw") == {:ok, [:video]}
    assert {:unresolved, _reason} = Shape.resolve(:scale, :inputs, w: "rw")
  end

  test "unsupported dynamic signatures remain unresolved, including sources" do
    for name <- [:movie, :amovie, :acrossover, :extractplanes, :streamselect] do
      assert {:unresolved, _reason} = Shape.resolve(name, :outputs)
    end

    assert Shape.resolve(:streamselect, :inputs, inputs: 3) ==
             {:ok, [:video, :video, :video]}

    assert Shape.resolve(:amix, :inputs, inputs: 3, inputs: 2) == {:ok, [:audio, :audio]}
    assert Shape.resolve(:hstack, :outputs, inputs: 3) == {:ok, [:video]}
  end
end
