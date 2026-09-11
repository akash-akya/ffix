defmodule FFix.ShortcutTest do
  use ExUnit.Case, async: true
  use FFix

  alias FFix.Command
  alias FFix.{Decoder, Demuxer, Encoder, Muxer}

  test "the common one-callback pipeline builds a graph and independently configured outputs" do
    source = Demuxer.mov("input.mp4") |> Decoder.h264({:video, 0}, threads: 2)

    built =
      command(
        source,
        fn input ->
          [main, preview] = split(video(input), outputs: 2)
          preview = scale(preview, w: 640, h: -2)

          [
            Muxer.mp4(
              [Encoder.libx264(main, crf: 18, preset: "slow"), stream_copy(audio(input))],
              "main.mp4",
              movflags: [:faststart]
            ),
            Muxer.matroska([Encoder.libx264(preview, crf: 28)], "preview.mkv",
              output_options: [t: 10]
            )
          ]
        end,
        global: [y: true]
      )

    argv = FFix.to_argv(built)
    assert values(argv, "-f") == ["mov", "mp4", "matroska"]
    assert values(argv, "-c:v:0") == ["h264"]
    assert values(argv, "-threads:v:0") == ["2"]
    assert values(argv, "-c:0") == ["libx264", "libx264"]
    assert values(argv, "-crf:0") == ["18", "28"]
    assert values(argv, "-c:1") == ["copy"]
    assert values(argv, "-movflags") == ["faststart"]
    assert values(argv, "-t") == ["10"]
    assert [graph] = values(argv, "-filter_complex")
    assert graph =~ "split=outputs=2"
    assert graph =~ "scale=w=640:h=-2"
  end

  test "named encoders remain reusable ordinary functions and do not emit defaults" do
    built =
      command("in.mp4", fn input ->
        Muxer.mp4([web_video(video(input)), web_video(video(input), crf: 28)], "out.mp4")
      end)

    argv = FFix.to_argv(built)
    assert values(argv, "-map") == ["0:v:0", "0:v:0"]
    assert values(argv, "-crf:0") == ["18"]
    assert values(argv, "-crf:1") == ["28"]
    assert values(argv, "-preset:0") == ["slow"]
    assert built.graph == nil

    default =
      command("in.mp4", fn input ->
        Muxer.mp4([Encoder.libx264(video(input))], "out.mp4")
      end)

    assert FFix.to_argv(default) == [
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

  test "selectors choose individual tracks without changing broad access semantics" do
    source = input("in.mkv")

    built =
      Command.new(
        inputs: [source],
        outputs: [Command.output([video(source, 1), audio(source, 2), source[:audio]], "out.mkv")]
      )

    assert values(FFix.to_argv(built), "-map") == ["0:v:1", "0:a:2", "0:a"]
    assert_raise ArgumentError, fn -> video(source, -1) end
  end

  test "decoders modify their input owner without invalidating previously built references" do
    original = input("in.mp4")
    selected = video(original)

    configured =
      original |> Decoder.h264({:video, 0}, threads: 2) |> Decoder.aac({:audio, 1}, threads: 1)

    built =
      command(configured, fn _input -> Muxer.mp4([stream_copy(selected)], "out.mp4") end)

    assert FFix.to_argv(built) == [
             "ffmpeg",
             "-c:a:1",
             "aac",
             "-threads:a:1",
             "1",
             "-c:v:0",
             "h264",
             "-threads:v:0",
             "2",
             "-i",
             "in.mp4",
             "-map",
             "0:v:0",
             "-c:0",
             "copy",
             "-f",
             "mp4",
             "out.mp4"
           ]

    assert_raise ArgumentError, ~r/expected an indexed video selector/, fn ->
      Decoder.h264(original, {:audio, 0}, threads: 2)
    end

    assert_raise ArgumentError, ~r/decoder selector must be/, fn ->
      Decoder.h264(original, {:video, -1}, [])
    end
  end

  test "automatic decoding emits only the requested options" do
    source = input("in.mp4") |> Decoder.auto({:video, 0}, threads: 2)
    built = command(source, fn input -> output([video(input)], "out.mp4") end)

    assert FFix.to_argv(built) == [
             "ffmpeg",
             "-threads:v:0",
             "2",
             "-i",
             "in.mp4",
             "-map",
             "0:v:0",
             "out.mp4"
           ]
  end

  test "demuxers separate AVOptions from raw input controls and support directional aliases" do
    source = Demuxer.mp4("in.bin", ignore_editlist: true, input_options: [ss: 5])
    built = command(source, fn input -> Muxer.mp4([stream_copy(video(input))], :stdout) end)

    assert FFix.to_argv(built) == [
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

  test "rawvideo shortcut handles format-specific vocabulary and rates" do
    source =
      Demuxer.rawvideo("frames.rgb", video_size: "1920x1080", pixel_format: :rgb24, framerate: 30)

    built = command(source, fn input -> Muxer.null([video(input)], "-") end)

    assert FFix.to_argv(built) == [
             "ffmpeg",
             "-f",
             "rawvideo",
             "-video_size",
             "1920x1080",
             "-pixel_format",
             "rgb24",
             "-framerate",
             "30",
             "-i",
             "frames.rgb",
             "-map",
             "0:v:0",
             "-f",
             "null",
             "-"
           ]
  end

  test "generic input and output constructors still accept independent configurations" do
    source =
      input("in.mp4",
        demuxer: Demuxer.new("mov"),
        decoders: %{{:video, 0} => Decoder.new("h264")}
      )

    built =
      command(source, fn input ->
        output([stream_copy(video(input))], "out.mp4",
          muxer: Muxer.new("mp4", movflags: "faststart")
        )
      end)

    assert values(FFix.to_argv(built), "-f") == ["mov", "mp4"]
    assert values(FFix.to_argv(built), "-movflags") == ["faststart"]

    explicit =
      Command.new(
        inputs: [source],
        outputs: [
          Command.output([stream_copy(video(source))], "out.mp4",
            muxer: Muxer.new("mp4", movflags: "faststart")
          )
        ]
      )

    assert FFix.to_argv(explicit) == FFix.to_argv(built)
  end

  test "muxer booleans remain valued while output switches remain bare" do
    built =
      command("in.mp4", fn input ->
        Muxer.mp4([Encoder.libx264(video(input), fastfirstpass: false)], "out.bin",
          empty_hdlr_name: true,
          movflags: [:faststart, :use_metadata_tags],
          output_options: [shortest: true]
        )
      end)

    argv = FFix.to_argv(built)
    assert values(argv, "-fastfirstpass:0") == ["false"]
    assert values(argv, "-empty_hdlr_name") == ["true"]
    assert values(argv, "-movflags") == ["faststart+use_metadata_tags"]
    assert List.last(argv) == "out.bin"
    assert Enum.take(argv, -2) == ["-shortest", "out.bin"]
  end

  test "helpers report misspelled option names and reject clearly incompatible values" do
    source = video(input("in.mp4"))

    assert_raise ArgumentError,
                 ~r/unknown libx264 encoder option "crrf".*Did you mean "crf"/,
                 fn ->
                   Encoder.libx264(source, crrf: 18)
                 end

    for options <- [[crf: true], [preset: 18], [fastfirstpass: %{}], [crf: nil]] do
      assert_raise ArgumentError, ~r/invalid value/, fn -> Encoder.libx264(source, options) end
    end

    assert_raise ArgumentError, ~r/expected a stream or graph export source/, fn ->
      Encoder.libx264(crf: 18)
    end
  end

  test "shared options are direction and media aware without overriding private types" do
    source = input("in.mp4")
    Encoder.libx264(video(source), profile: "high", b: "2M", threads: 2)
    Encoder.h264_nvenc(video(source), preset: :p5)
    Encoder.libopus(audio(source), application: :audio, b: "96k")
    Decoder.h264(source, {:video, 0}, skip_frame: :nokey)

    assert_raise ArgumentError, ~r/unknown libx264 encoder option "skip_frame"/, fn ->
      Encoder.libx264(video(source), skip_frame: :nokey)
    end

    assert_raise ArgumentError, ~r/unknown aac encoder option "g"/, fn ->
      Encoder.aac(audio(source), g: 24)
    end
  end

  test "raw values and new option names remain explicit escape hatches" do
    source = input("in.mp4")
    mapping = Encoder.libx264(video(source), crf: "18", raw: [{"future_option", "a=b:c=d"}])
    built = command(source, fn _input -> Muxer.mp4([mapping], "out.mp4") end)
    assert values(FFix.to_argv(built), "-future_option:0") == ["a=b:c=d"]

    assert_raise ArgumentError, ~r/duplicate option/, fn ->
      Encoder.libx264(video(source), crf: 18, raw: [{"crf", 28}])
    end

    assert_raise ArgumentError, ~r/unscoped names/, fn ->
      Encoder.libx264(video(source), raw: [{"threads:v:0", 2}])
    end

    assert_raise ArgumentError, ~r/CLI control/, fn ->
      Encoder.libx264(video(source), raw: [{"c", "copy"}])
    end
  end

  test "flag lists check reported atoms but leave strings open" do
    source = video(input("in.mp4"))
    assert Muxer.mp4([source], "out.mp4", movflags: []).muxer.options == [{"movflags", "0"}]

    assert Muxer.mp4([source], "out.mp4", movflags: ["future_flag"]).muxer.options == [
             {"movflags", "future_flag"}
           ]

    assert_raise ArgumentError, ~r/invalid value/, fn ->
      Muxer.mp4([source], "out.mp4", movflags: [:faststrt])
    end

    assert_raise ArgumentError, ~r/unknown hevc decoder option "view_ids_available"/, fn ->
      Decoder.hevc(input("in.mp4"), {:video, 0}, view_ids_available: "0")
    end
  end

  test "duplicate special bindings and malformed options do not silently disappear" do
    source = video(input("in.mp4"))

    assert_raise ArgumentError, ~r/duplicate option/, fn ->
      Muxer.mp4(source, "out.mp4", output_options: [], output_options: [])
    end

    assert_raise ArgumentError, ~r/duplicate option/, fn ->
      Encoder.libx264(source, [{:crf, 18}, {"crf", 28}])
    end

    assert_raise ArgumentError, ~r/duplicate option/, fn ->
      Encoder.libx264(source, raw: [], raw: [])
    end

    assert_raise ArgumentError, ~r/options must be a list/, fn ->
      Demuxer.mov("in.mp4", input_options: nil)
    end

    assert_raise ArgumentError, ~r/expects an input declaration/, fn ->
      Decoder.h264(source, {:video, 0})
    end
  end

  test "operation helpers are pipe-friendly with only options optional" do
    source =
      "in.mp4"
      |> Demuxer.demux("mov")
      |> Decoder.decode("h264", {:video, 1})
      |> Decoder.aac({:audio, 1})

    assert source.demuxer == Demuxer.new("mov")

    assert source.decoders == %{
             {:video, 1} => Decoder.new("h264"),
             {:audio, 1} => Decoder.new("aac")
           }

    mapped = source |> video(1) |> Encoder.encode("h264")
    assert mapped.encoding == Encoder.new("h264")
    assert mapped |> Muxer.mux("mp4", "out.mp4") == Muxer.mp4(mapped, "out.mp4")

    configured =
      source
      |> video(1)
      |> Encoder.encode("h264", crf: 23, preset: "slow", "x264-params": "keyint=48")

    output = configured |> Muxer.mux("mp4", "out.mp4", movflags: "faststart")
    argv = Command.new(inputs: [source], outputs: [output]) |> FFix.to_argv()
    assert values(argv, "-c:0") == ["h264"]
    assert values(argv, "-crf:0") == ["23"]
    assert values(argv, "-preset:0") == ["slow"]
    assert values(argv, "-x264-params:0") == ["keyint=48"]
    assert values(argv, "-movflags") == ["faststart"]
  end

  test "decoder helpers require an explicit indexed selector" do
    source = input("in.mp4")

    assert_raise ArgumentError, ~r/expected an indexed video selector/, fn ->
      Decoder.h264(source, threads: 2)
    end

    for selector <- [:video, {:raw, "v:0"}, {:video, -1}, nil, []] do
      assert_raise ArgumentError, ~r/decoder selector must be/, fn ->
        Decoder.decode(source, "h264", selector)
      end

      assert_raise ArgumentError, ~r/decoder selector must be/, fn ->
        Decoder.auto(source, selector)
      end
    end
  end

  test "generic operation helpers replace named without compatibility aliases" do
    for {module, operation, arities} <- [
          {Encoder, :encode, [2, 3]},
          {Decoder, :decode, [3, 4]},
          {Demuxer, :demux, [2, 3]},
          {Muxer, :mux, [3, 4]}
        ] do
      functions = module.__info__(:functions)
      assert Keyword.get_values(functions, operation) == arities
      refute Keyword.has_key?(functions, :named)
    end

    assert Keyword.get_values(Decoder.__info__(:functions), :auto) == [2, 3]
  end

  test "muxer sources are required rather than hidden in options" do
    source = video(input("in.mp4"))

    for sources <- [[], nil] do
      assert_raise ArgumentError, "output requires at least one source", fn ->
        Muxer.mp4(sources, "out.mp4")
      end

      assert_raise ArgumentError, "output requires at least one source", fn ->
        Muxer.mux(sources, "mp4", "out.mp4")
      end
    end

    assert_raise ArgumentError, ~r/invalid output source\/target/, fn ->
      Muxer.mp4("out.mp4", sources: [source])
    end

    for option <- [:video, :audio, :sources] do
      assert_raise ArgumentError, ~r/unknown mp4 muxer option/, fn ->
        Muxer.mp4(source, "out.mp4", [{option, source}])
      end
    end
  end

  test "dynamic names do not need a generated registration" do
    source = Demuxer.demux("in.data", "vendor_demuxer", [{"custom", "yes"}])
    source = Decoder.decode(source, "vendor_decoder", {:video, 0}, [{"custom", "decode"}])

    built =
      command(source, fn input ->
        mapped = Encoder.encode(video(input), "vendor_encoder", [{"custom", "encode"}])
        Muxer.mux([mapped], "vendor_muxer", "out.data", raw: [{"custom", "mux"}])
      end)

    argv = FFix.to_argv(built)
    assert values(argv, "-f") == ["vendor_demuxer", "vendor_muxer"]
    assert values(argv, "-c:v:0") == ["vendor_decoder"]
    assert values(argv, "-c:0") == ["vendor_encoder"]
    assert values(argv, "-custom") == ["yes", "mux"]
    assert values(argv, "-custom:v:0") == ["decode"]
    assert values(argv, "-custom:0") == ["encode"]
  end

  test "raw input format selection cannot silently override a demuxer helper" do
    source = Demuxer.mov("in.mp4", input_options: [f: "matroska"])
    built = command(source, fn input -> output([video(input)], "out.mp4") end)

    assert_raise ArgumentError, ~r/cannot be combined with a structured demuxer/, fn ->
      FFix.to_argv(built)
    end
  end

  test "one-callback construction preserves named inputs and accepts filter sources without inputs" do
    built =
      command(%{main: "in.mp4", music: "in.wav"}, fn inputs ->
        Muxer.mp4(
          [Encoder.libx264(video(inputs.main)), Encoder.aac(audio(inputs.music))],
          "out.mp4"
        )
      end)

    argv = FFix.to_argv(built)
    assert values(argv, "-i") == ["in.mp4", "in.wav"]
    assert values(argv, "-map") == ["0:v:0", "1:a:0"]

    generated =
      command([], fn [] ->
        Muxer.null([testsrc(size: "16x16", duration: 0.1)], "-")
      end)

    assert values(FFix.to_argv(generated), "-i") == []
    assert [_graph] = values(FFix.to_argv(generated), "-filter_complex")
  end

  test "explicit graph/output callbacks continue to work with shortcuts" do
    built =
      command(
        "in.mp4",
        fn source -> scale(video(source), w: 320, h: -2) end,
        fn scaled, source ->
          Muxer.mp4([Encoder.libx264(scaled), stream_copy(audio(source))], "out.mp4")
        end
      )

    assert values(FFix.to_argv(built), "-c:0") == ["libx264"]
    assert values(FFix.to_argv(built), "-c:1") == ["copy"]
  end

  test "automatic graphs do not insert splits or permit copying filtered outputs" do
    copied =
      command("in.mp4", fn source ->
        Muxer.mp4([stream_copy(scale(video(source), w: 320, h: -2))], "out.mp4")
      end)

    assert_raise ArgumentError, ~r/cannot copy a filtered source/, fn -> FFix.to_argv(copied) end

    duplicated =
      command("in.mp4", fn source ->
        mapped = video(source) |> scale(w: 320, h: -2) |> Encoder.libx264()
        [Muxer.mp4([mapped], "first.mp4"), Muxer.mp4([mapped], "second.mp4")]
      end)

    assert_raise ArgumentError, ~r/is used 2 times/, fn -> FFix.to_argv(duplicated) end
  end

  test "the copy filter remains distinct from packet-level stream copy" do
    built =
      command("in.mp4", fn source ->
        Muxer.mp4([source |> video() |> copy() |> Encoder.libx264()], "out.mp4")
      end)

    assert [graph] = values(FFix.to_argv(built), "-filter_complex")
    assert graph =~ "copy"
    assert values(FFix.to_argv(built), "-c:0") == ["libx264"]
  end

  defp web_video(source, options \\ []) do
    Encoder.libx264(source, Keyword.merge([crf: 18, preset: "slow"], options))
  end

  defp values(argv, key) do
    argv
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn pair ->
      case pair do
        [^key, value] -> [value]
        _other -> []
      end
    end)
  end
end
