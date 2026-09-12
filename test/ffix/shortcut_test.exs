defmodule FFix.ShortcutTest do
  use ExUnit.Case, async: true

  alias FFix.{Decoder, Demuxer, Encoder, Filter, Muxer}

  test "named helpers compose decoding, filtering, encoding, and independent muxers" do
    input = Demuxer.mov("input.mp4") |> Decoder.h264({:video, 0}, threads: 2)
    [main, preview] = Filter.split(FFix.video(input, 0))
    preview = Filter.scale(preview, w: 640, h: -2)

    command =
      FFix.command([
        Muxer.mp4(
          [Encoder.libx264(main, crf: 18), FFix.stream_copy(FFix.audio(input, 0))],
          "main.mp4",
          movflags: [:faststart]
        ),
        Muxer.matroska(Encoder.libx264(preview, crf: 28), "preview.mkv", output_options: [t: 10])
      ])

    argv = FFix.to_argv(command)
    assert values(argv, "-f") == ["mov", "mp4", "matroska"]
    assert values(argv, "-c:v:0") == ["h264"]
    assert values(argv, "-threads:v:0") == ["2"]
    assert values(argv, "-c:0") == ["libx264", "libx264"]
    assert values(argv, "-crf:0") == ["18", "28"]
    assert values(argv, "-c:1") == ["copy"]
    assert values(argv, "-movflags") == ["faststart"]
    assert values(argv, "-t") == ["10"]
    assert [graph] = values(argv, "-filter_complex")
    assert graph =~ "split"
    assert graph =~ "scale=w=640:h=-2"
  end

  test "named encoders do not emit metadata defaults" do
    source = FFix.input("in.mp4") |> FFix.video(0)
    command = Encoder.libx264(source) |> Muxer.mp4("out.mp4") |> FFix.command()

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-i",
             "in.mp4",
             "-map",
             "0:v:0",
             "-c:0",
             "libx264",
             "-f",
             "mp4",
             "out.mp4"
           ]
  end

  test "demuxers separate AVOptions from raw input controls and support directional aliases" do
    input = Demuxer.mp4("in.bin", ignore_editlist: true, input_options: [ss: 5])
    command = input |> FFix.video(0) |> FFix.stream_copy() |> Muxer.mp4(:stdout) |> FFix.command()

    assert FFix.to_argv(command) == [
             "ffmpeg",
             "-ss",
             "5",
             "-f",
             "mp4",
             "-ignore_editlist",
             "true",
             "-i",
             "in.bin",
             "-map",
             "0:v:0",
             "-c:0",
             "copy",
             "-f",
             "mp4",
             "pipe:1"
           ]
  end

  test "rawvideo helpers normalize format-specific sizes, pixel formats, and rates" do
    input =
      Demuxer.rawvideo("frames.rgb", video_size: "1920x1080", pixel_format: :rgb24, framerate: 30)

    assert input.demuxer.options == [
             {"video_size", "1920x1080"},
             {"pixel_format", "rgb24"},
             {"framerate", 30}
           ]
  end

  test "helpers report misspelled option names and reject incompatible value shapes" do
    source = FFix.input("in.mp4") |> FFix.video(0)

    assert_raise ArgumentError,
                 ~r/unknown libx264 encoder option "crrf".*Did you mean "crf"/,
                 fn -> Encoder.libx264(source, crrf: 18) end

    for options <- [[crf: true], [preset: 18], [fastfirstpass: %{}], [crf: nil]] do
      assert_raise ArgumentError, ~r/invalid value/, fn -> Encoder.libx264(source, options) end
    end
  end

  test "shared options respect direction and media while private types take precedence" do
    input = FFix.input("in.mp4")
    video = FFix.video(input, 0)
    audio = FFix.audio(input, 0)

    assert Encoder.libx264(video, profile: "high", b: "2M", threads: 2).encoding.options ==
             [{"profile", "high"}, {"b", "2M"}, {"threads", 2}]

    assert Encoder.h264_nvenc(video, preset: :p5).encoding.options == [{"preset", "p5"}]

    assert Encoder.libopus(audio, application: :audio, b: "96k").encoding.options ==
             [{"application", "audio"}, {"b", "96k"}]

    assert Decoder.h264(input, {:video, 0}, skip_frame: :nokey).decoders[{:video, 0}].options ==
             [{"skip_frame", "nokey"}]

    assert_raise ArgumentError, ~r/unknown libx264 encoder option "skip_frame"/, fn ->
      Encoder.libx264(video, skip_frame: :nokey)
    end

    assert_raise ArgumentError, ~r/unknown aac encoder option "g"/, fn ->
      Encoder.aac(audio, g: 24)
    end

    assert_raise ArgumentError, ~r/unknown hevc decoder option "view_ids_available"/, fn ->
      Decoder.hevc(input, {:video, 0}, view_ids_available: "0")
    end
  end

  test "raw options bypass metadata but retain scoping and conflict checks" do
    source = FFix.input("in.mp4") |> FFix.video(0)
    mapping = Encoder.libx264(source, crf: "18", raw: [{"future_option", "a=b:c=d"}])
    command = mapping |> Muxer.mp4("out.mp4") |> FFix.command()
    assert values(FFix.to_argv(command), "-future_option:0") == ["a=b:c=d"]

    assert_raise ArgumentError, ~r/duplicate option/, fn ->
      Encoder.libx264(source, crf: 18, raw: [{"crf", 28}])
    end

    assert_raise ArgumentError, ~r/unscoped names/, fn ->
      Encoder.libx264(source, raw: [{"threads:v:0", 2}])
    end

    assert_raise ArgumentError, ~r/CLI control/, fn ->
      Encoder.libx264(source, raw: [{"c", "copy"}])
    end
  end

  test "flag lists normalize empty and named flags while allowing future strings" do
    source = FFix.input("in.mp4") |> FFix.video(0)

    for {flags, expected} <- [
          {[], "0"},
          {[:faststart, :use_metadata_tags], "faststart+use_metadata_tags"},
          {["future_flag"], "future_flag"}
        ] do
      assert Muxer.mp4(source, "out.mp4", movflags: flags).muxer.options ==
               [{"movflags", expected}]
    end

    assert_raise ArgumentError, ~r/invalid value/, fn ->
      Muxer.mp4(source, "out.mp4", movflags: [:faststrt])
    end
  end

  test "duplicate special bindings and malformed options do not silently disappear" do
    source = FFix.input("in.mp4") |> FFix.video(0)

    assert_raise ArgumentError, ~r/duplicate option/, fn ->
      Muxer.mp4(source, "out.mp4", output_options: [], output_options: [])
    end

    for options <- [[{:crf, 18}, {"crf", 28}], [raw: [], raw: []]] do
      assert_raise ArgumentError, ~r/duplicate option/, fn ->
        Encoder.libx264(source, options)
      end
    end

    assert_raise ArgumentError, ~r/options must be a list/, fn ->
      Demuxer.mov("in.mp4", input_options: nil)
    end

    assert_raise ArgumentError, ~r/expects an input declaration/, fn ->
      Decoder.h264(source, {:video, 0})
    end
  end

  test "automatic and named decoding require indexed selectors with compatible media" do
    input = FFix.input("in.mp4")
    configured = Decoder.auto(input, {:video, 0}, threads: 2)
    assert configured.decoders == %{{:video, 0} => %Decoder{options: [{"threads", 2}]}}

    assert_raise ArgumentError, ~r/expected an indexed video selector/, fn ->
      Decoder.h264(input, {:audio, 0})
    end

    for selector <- [:video, {:raw, "v:0"}, {:video, -1}, nil] do
      assert_raise ArgumentError, ~r/decoder selector must be/, fn ->
        Decoder.h264(input, selector)
      end

      assert_raise ArgumentError, ~r/decoder selector must be/, fn ->
        Decoder.auto(input, selector)
      end
    end
  end

  test "generic codec names stay literal rather than selecting an implementation" do
    input = FFix.input("in.mp4")
    mapping = input |> FFix.video(0) |> Encoder.encode("h264", crf: 23, preset: "slow")
    command = mapping |> Muxer.mux("mp4", "out.mp4") |> FFix.command()
    argv = FFix.to_argv(command)
    assert values(argv, "-c:0") == ["h264"]
    assert values(argv, "-crf:0") == ["23"]
    assert values(argv, "-preset:0") == ["slow"]
  end

  test "generic helpers preserve unregistered names and options as literal arguments" do
    input = Demuxer.demux("in.data", "vendor_demuxer", custom: "demux")
    input = Decoder.decode(input, "vendor_decoder", {:video, 0}, custom: "decode")
    mapped = input |> FFix.video(0) |> Encoder.encode("vendor;encoder", custom: "encode")
    command = mapped |> Muxer.mux("vendor_muxer", "out.data", custom: "mux") |> FFix.command()
    argv = FFix.to_argv(command)
    assert values(argv, "-f") == ["vendor_demuxer", "vendor_muxer"]
    assert values(argv, "-c:v:0") == ["vendor_decoder"]
    assert values(argv, "-c:0") == ["vendor;encoder"]
    assert values(argv, "-custom") == ["demux", "mux"]
    assert values(argv, "-custom:v:0") == ["decode"]
    assert values(argv, "-custom:0") == ["encode"]
  end

  test "raw input format selection cannot override a demuxer helper" do
    assert_raise ArgumentError, ~r/cannot be combined with a structured demuxer/, fn ->
      input = Demuxer.mov("in.mp4", input_options: [f: "matroska"])
      input |> FFix.video(0) |> FFix.output("out.mp4") |> FFix.command()
    end
  end

  test "the copy filter remains distinct from packet-level stream copy" do
    source = FFix.input("in.mp4") |> FFix.video(0) |> Filter.copy() |> Encoder.libx264()
    command = source |> Muxer.mp4("out.mp4") |> FFix.command()
    argv = FFix.to_argv(command)
    assert [graph] = values(argv, "-filter_complex")
    assert graph =~ "copy"
    assert values(argv, "-c:0") == ["libx264"]
  end

  defp values(argv, key) do
    argv
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn
      [^key, value] -> [value]
      _other -> []
    end)
  end
end
