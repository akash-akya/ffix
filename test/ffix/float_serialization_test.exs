defmodule FFix.FloatSerializationTest do
  use ExUnit.Case, async: true

  alias FFix.{Command, Filter, Graph, Value}
  @ffmpeg System.find_executable("ffmpeg")

  test "float values use decimal notation without losing small or large values" do
    for value <- [0.0, -0.0, 0.2, -0.00001, 1.0e-20, 1.0e21, 1.2345678901234567] do
      decimal = Value.float_to_string(value)
      refute decimal =~ "e"
      assert {^value, ""} = Float.parse(decimal)
    end

    assert Value.float_to_string(0.2) == "0.2"
    assert Value.float_to_string(1.0e-6) == "0.000001"
    assert Value.float_to_string(1.0e21) == "1000000000000000000000"
  end

  test "graph, input, output, and component floats use the same decimal encoding" do
    graph = FFix.graph(output: Filter.sine(duration: 0.2))
    assert FFix.to_filtergraph(graph) == "sine=duration=0.2[out0];"

    source = FFix.input("in.wav", ss: 0.2)
    mapping = FFix.Encoder.encode(FFix.audio(source, 0), "aac", q: 1.0e-20)
    output = FFix.output(mapping, "out.mka", t: 1.0e-6)
    argv = Command.new(inputs: [source], outputs: [output]) |> FFix.to_argv()
    assert Enum.chunk_every(argv, 2, 1, :discard) |> Enum.member?(["-ss", "0.2"])
    assert Enum.chunk_every(argv, 2, 1, :discard) |> Enum.member?(["-t", "0.000001"])

    assert Enum.chunk_every(argv, 2, 1, :discard)
           |> Enum.member?(["-q:0", "0.00000000000000000001"])
  end

  @tag skip: is_nil(@ffmpeg)
  test "FFmpeg accepts fractional and microsecond filter durations" do
    for duration <- [0.01, 1.0e-5, 1.0e-6] do
      graph = FFix.graph(output: Filter.sine(duration: duration))

      {log, status} =
        System.cmd(
          @ffmpeg,
          [
            "-v",
            "error",
            "-filter_complex",
            Graph.to_filtergraph(graph),
            "-map",
            "[out0]",
            "-frames:a",
            "1",
            "-f",
            "null",
            "-"
          ],
          stderr_to_stdout: true
        )

      assert status == 0, log
    end
  end
end
