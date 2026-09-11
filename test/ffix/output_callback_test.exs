defmodule FFix.OutputCallbackTest do
  use ExUnit.Case, async: true
  use FFix

  alias FFix.Command
  alias FFix.Command.Mapping
  alias FFix.{Decoder, Demuxer, Encoder, Muxer}

  test "the issue's HLS references follow final mapping order, independently of input order" do
    built = hls_command()

    assert values(FFix.to_argv(built), "-var_stream_map") == [
             "v:0,agroup:a,name:720p v:1,agroup:a,name:360p a:0,agroup:a,name:audio,default:yes"
           ]

    [output] = built.outputs
    [high, low, sound] = output.mappings
    assert Enum.map(output.mappings, & &1.name) == [:v720, :v360, :aud]
    output = %{output | mappings: [sound, low, high]}
    built = %{built | outputs: [output], inputs: Enum.reverse(built.inputs)}
    argv = FFix.to_argv(built)

    assert values(argv, "-var_stream_map") == [
             "v:1,agroup:a,name:720p v:0,agroup:a,name:360p a:0,agroup:a,name:audio,default:yes"
           ]

    assert values(argv, "-c:0") == ["aac"]
    assert values(argv, "-b:0") == ["64k"]
    assert values(argv, "-b:1") == ["400k"]
    assert values(argv, "-b:2") == ["800k"]
    assert [graph] = values(argv, "-filter_complex")
    assert graph =~ "[1:v:0]"
    assert "1:a:0" in values(argv, "-map")
  end

  test "callbacks are deferred, evaluated once per option per serialization, and never cached" do
    parent = self()

    callback = fn streams ->
      send(parent, {:called, streams.main})
      "title=#{streams.main.specifier}"
    end

    built =
      command("in.mp4", fn source ->
        output([main: video(source)], "out.mp4", metadata: callback)
      end)

    Command.validate!(built)
    refute_received {:called, _info}

    for _pass <- 1..2 do
      assert values(FFix.to_argv(built), "-metadata") == ["title=v:0"]
      assert_received {:called, %{index: 0, specifier: "v:0"}}
      refute_received {:called, _info}
    end

    assert is_function(hd(built.outputs).options[:metadata], 1)
  end

  test "unnamed mappings affect indexes but do not acquire implicit names" do
    built =
      command("in.mp4", fn source ->
        mappings = [audio(source), video(source), {:main, video(source)}]

        output(
          mappings,
          "out.mp4",
          metadata: fn streams ->
            assert streams == %{main: %{index: 2, specifier: "v:1"}}
            "title=track-#{streams.main.index}"
          end
        )
      end)

    assert values(FFix.to_argv(built), "-metadata") == ["title=track-2"]
  end

  test "names and indexes are local to each output" do
    built =
      command("in.mp4", fn source ->
        [
          output(
            [sound: audio(source), main: video(source)],
            "first.mp4",
            metadata: fn streams ->
              assert streams.main == %{index: 1, specifier: "v:0"}
              "title=first"
            end
          ),
          output(
            [main: video(source)],
            "second.mp4",
            metadata: fn streams ->
              assert streams == %{main: %{index: 0, specifier: "v:0"}}
              "title=second"
            end
          )
        ]
      end)

    assert values(FFix.to_argv(built), "-metadata") == ["title=first", "title=second"]
  end

  test "named bindings also work without callbacks and do not mutate reusable mappings" do
    source = input("in.mp4")
    mapping = Encoder.libx264(video(source))
    output = Command.output([first: mapping, second: mapping], "out.mp4")
    assert mapping.name == nil
    assert Enum.map(output.mappings, & &1.name) == [:first, :second]
    built = Command.new(inputs: [source], outputs: [output])
    assert values(FFix.to_argv(built), "-c:0") == ["libx264"]
    assert values(FFix.to_argv(built), "-c:1") == ["libx264"]
  end

  test "encoder, muxer, and raw output options all support callbacks with normal value rendering" do
    parent = self()

    built =
      command("in.mp4", fn source ->
        mapping =
          Encoder.libx264(video(source),
            threads: fn streams -> streams.main.index + 1 end,
            fastfirstpass: fn _streams -> false end
          )

        Muxer.mp4(
          [main: mapping],
          "out.mp4",
          movflags: fn streams ->
            send(parent, {:muxer_callback, streams})
            [:faststart, :use_metadata_tags]
          end,
          output_options: [shortest: fn _streams -> true end]
        )
      end)

    refute_received {:muxer_callback, _streams}
    argv = FFix.to_argv(built)
    assert values(argv, "-threads:0") == ["1"]
    assert values(argv, "-fastfirstpass:0") == ["false"]
    assert values(argv, "-movflags") == ["faststart+use_metadata_tags"]
    assert Enum.take(argv, -2) == ["-shortest", "out.mp4"]
    assert_received {:muxer_callback, %{main: %{index: 0, specifier: "v:0"}}}
    refute_received {:muxer_callback, _streams}
  end

  test "dynamic names, standalone configurations, and raw metadata escapes work too" do
    source = input("in.mp4")
    encoder = Encoder.new("vendor", custom: fn streams -> streams.main.specifier end)
    mapping = Mapping.new(video(source), encoder)
    muxer = Muxer.new("vendor_muxer", custom: fn streams -> streams.main.index end)
    output = Command.output([main: mapping], "out.bin", muxer: muxer)
    built = Command.new(inputs: [source], outputs: [output])
    assert values(FFix.to_argv(built), "-custom:0") == ["v:0"]
    assert values(FFix.to_argv(built), "-custom") == ["0"]

    built =
      command(source, fn source ->
        Muxer.mp4(
          [main: video(source)],
          "out.mp4",
          raw: [future: fn streams -> streams.main.specifier end]
        )
      end)

    assert values(FFix.to_argv(built), "-future") == ["v:0"]
  end

  test "named helpers check keys immediately and callback results during serialization" do
    source = input("in.mp4")
    callback = fn _streams -> raise "should not run" end

    assert_raise ArgumentError, ~r/unknown libx264 encoder option/, fn ->
      Encoder.libx264(video(source), crrf: callback)
    end

    built =
      command(source, fn source ->
        output(
          [main: Encoder.libx264(video(source), crf: fn _streams -> true end)],
          "out.mp4"
        )
      end)

    Command.validate!(built)

    assert_raise ArgumentError, ~r/invalid value true for libx264 encoder option/, fn ->
      FFix.to_argv(built)
    end

    built =
      command(source, fn source ->
        Muxer.mp4(
          [main: video(source)],
          "out.mp4",
          movflags: fn _streams -> [:misspelled_flag] end
        )
      end)

    assert_raise ArgumentError, ~r/invalid value/, fn -> FFix.to_argv(built) end
  end

  test "bad callback results and arities are rejected without executing nested callbacks" do
    for callback <- [fn _streams -> %{} end, fn _streams -> fn _nested -> "bad" end end] do
      built =
        command("in.mp4", fn source ->
          output([main: video(source)], "out.mp4", metadata: callback)
        end)

      assert_raise ArgumentError, fn -> FFix.to_argv(built) end
    end

    built =
      command("in.mp4", fn source ->
        output([main: video(source)], "out.mp4", metadata: fn -> "bad" end)
      end)

    assert_raise ArgumentError, ~r/must accept one streams argument/, fn ->
      FFix.to_argv(built)
    end

    for value <- [nil, %{}, [:not_a_scalar]] do
      built =
        command("in.mp4", fn source ->
          mapping = Encoder.encode(video(source), "vendor", custom: fn _streams -> value end)
          output([main: mapping], "out.mp4")
        end)

      assert_raise ArgumentError, ~r/component option values must be/, fn ->
        FFix.to_argv(built)
      end
    end
  end

  test "missing names and user exceptions propagate instead of being masked" do
    built =
      command("in.mp4", fn source ->
        output(
          [main: video(source)],
          "out.mp4",
          metadata: fn streams -> streams.missing.specifier end
        )
      end)

    assert_raise KeyError, ~r/key :missing not found/, fn -> FFix.to_argv(built) end

    built =
      command("in.mp4", fn source ->
        output(
          [main: video(source)],
          "out.mp4",
          metadata: fn _streams -> raise "application error" end
        )
      end)

    assert_raise RuntimeError, "application error", fn -> FFix.to_argv(built) end
  end

  test "duplicate and invalid mapping names fail before callbacks" do
    source = input("in.mp4")
    callback = fn _streams -> flunk("must not run") end

    output =
      Command.output([main: video(source), main: audio(source)], "out.mp4", metadata: callback)

    built = Command.new(inputs: [source], outputs: [output])

    assert_raise ArgumentError, ~r/duplicate output mapping name: :main/, fn ->
      FFix.to_argv(built)
    end

    for name <- ["main", true, false, 1] do
      output =
        Command.output(%Mapping{source: video(source), name: name}, "out.mp4", metadata: callback)

      built = Command.new(inputs: [source], outputs: [output])
      assert_raise ArgumentError, ~r/output mapping name must be/, fn -> FFix.to_argv(built) end
    end
  end

  test "callbacks reject broad and raw selections, including unnamed and exported selections" do
    source = input("in.mp4")

    for selector <- [:video, :audio, :input, {:raw, "v:0"}, {:raw, "a:0?"}] do
      broad = source[selector]
      callback = fn _streams -> flunk("must not run") end
      output = Command.output([video(source), {:broad, broad}], "out.mp4", metadata: callback)
      built = Command.new(inputs: [source], outputs: [output])

      assert_raise ArgumentError, ~r/callbacks require every mapping to select one stream/, fn ->
        FFix.to_argv(built)
      end

      graph = FFix.graph(outputs: [broad: broad])
      output = Command.output(graph[:broad], "out.mp4", metadata: callback)
      built = Command.new(inputs: [source], graph: graph, outputs: [output])

      assert_raise ArgumentError, ~r/callbacks require every mapping to select one stream/, fn ->
        FFix.to_argv(built)
      end
    end
  end

  test "raw mapping changes and extra inputs cannot invalidate callback indexes" do
    source = input("in.mp4")

    for name <- [:map, :an, :attach, :filter_complex] do
      output =
        Command.output([main: video(source)], "out.mp4", [
          {name, fn _streams -> flunk("must not run") end}
        ])

      built = Command.new(inputs: [source], outputs: [output])

      assert_raise ArgumentError, ~r/cannot be combined with output option callbacks/, fn ->
        FFix.to_argv(built)
      end
    end

    output =
      Command.output([main: video(source)], "out.mp4",
        metadata: fn _streams -> flunk("must not run") end
      )

    built = Command.new(inputs: [source], outputs: [output], global: [i: "extra.mp4"])

    assert_raise ArgumentError, ~r/cannot be combined with configured mappings/, fn ->
      FFix.to_argv(built)
    end

    source = %{source | options: [i: "extra.mp4"]}
    built = Command.new(inputs: [source], outputs: [output])

    assert_raise ArgumentError, ~r/cannot be combined with configured mappings/, fn ->
      FFix.to_argv(built)
    end
  end

  test "callbacks are not accepted on inputs or global options" do
    callback = fn _streams -> flunk("must not run") end

    assert_raise ArgumentError, ~r/only supported on outputs/, fn ->
      Decoder.new("h264", threads: callback)
    end

    assert_raise ArgumentError, ~r/only supported on outputs/, fn ->
      Demuxer.new("mov", probesize: callback)
    end

    source = input("in.mp4", ss: callback)
    built = command(source, fn source -> output([video(source)], "out.mp4") end)
    assert_raise ArgumentError, ~r/only supported on outputs/, fn -> FFix.to_argv(built) end

    built =
      command("in.mp4", fn source -> output([video(source)], "out.mp4") end,
        global: [loglevel: callback]
      )

    assert_raise ArgumentError, ~r/only supported on outputs/, fn -> FFix.to_argv(built) end
  end

  test "mixed-media filter exports retain per-pad media in both callback forms" do
    check = fn streams ->
      assert streams == %{
               sound: %{index: 0, specifier: "a:0"},
               picture: %{index: 1, specifier: "v:0"}
             }

      "title=mixed"
    end

    build_streams = fn source -> concat([video(source), audio(source)], n: 1, v: 1, a: 1) end

    built =
      command("in.mp4", fn source ->
        [picture, sound] = build_streams.(source)
        output([sound: sound, picture: picture], "out.mp4", metadata: check)
      end)

    assert values(FFix.to_argv(built), "-metadata") == ["title=mixed"]

    built =
      command("in.mp4", build_streams, fn [picture, sound] ->
        output([sound: sound, picture: picture], "out.mp4", metadata: check)
      end)

    assert values(FFix.to_argv(built), "-metadata") == ["title=mixed"]
  end

  test "parsed graph references use output media, not the input media of converting filters" do
    source = input("in.mp4")
    graph = FFix.Graph.parse!("[0:a:0]showwaves=s=320x100[wave]")

    output =
      Command.output([main: graph[:wave]], "out.mp4",
        metadata: fn streams -> streams.main.specifier end
      )

    built = Command.new(inputs: [source], graph: graph, outputs: [output])
    assert values(FFix.to_argv(built), "-metadata") == ["v:0"]
  end

  test "unknown output media is rejected rather than guessed" do
    built =
      command("in.mp4", fn source ->
        unknown = source |> video() |> FFix.Filter.filter("null", [:unknown])

        output(
          [main: unknown],
          "out.mp4",
          metadata: fn _streams -> flunk("must not run") end
        )
      end)

    assert_raise ArgumentError, ~r/require known audio\/video media/, fn ->
      FFix.to_argv(built)
    end
  end

  defp hls_command do
    source = input("in.mp4")
    other = input("other.mp4")

    command([source, other], fn [source, _other] ->
      [high, low] = split(video(source), outputs: 2)

      high =
        high
        |> scale(w: -2, h: 720)
        |> Encoder.libx264(b: "800k", maxrate: "800k", bufsize: "1600k")

      low =
        low
        |> scale(w: -2, h: 360)
        |> Encoder.libx264(b: "400k", maxrate: "400k", bufsize: "800k", g: 12)

      sound = Encoder.aac(audio(source), b: "64k")

      Muxer.hls(
        [v720: high, v360: low, aud: sound],
        "out/%v.m3u8",
        hls_time: 2,
        var_stream_map: fn streams ->
          "#{streams.v720.specifier},agroup:a,name:720p " <>
            "#{streams.v360.specifier},agroup:a,name:360p " <>
            "#{streams.aud.specifier},agroup:a,name:audio,default:yes"
        end
      )
    end)
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
