defmodule FFix.CommandConfigurationTest do
  use ExUnit.Case, async: true

  alias FFix.Command
  alias FFix.Command.{Mapping, Output}
  alias FFix.{Decoder, Encoder, Filter, Muxer}

  test "maps one video twice with independent encoders after copied audio" do
    input = Command.input("source.mkv")

    output = %Output{
      target: "qualities.mkv",
      mappings: [
        %Mapping{source: input[audio: 0], encoding: :copy},
        %Mapping{
          source: input[video: 0],
          encoding: %Encoder{name: "libx264", options: [{"crf", 18}]}
        },
        %Mapping{
          source: input[video: 0],
          encoding: %Encoder{name: "libx264", options: [{"crf", 28}]}
        }
      ],
      muxer: %Muxer{name: "matroska"},
      options: [t: 0.5]
    }

    command = %Command{inputs: [input], outputs: [output]}

    assert Command.to_argv(command) == [
             "ffmpeg",
             "-i",
             "source.mkv",
             "-map",
             "0:a:0",
             "-map",
             "0:v:0",
             "-map",
             "0:v:0",
             "-c:0",
             "copy",
             "-c:1",
             "libx264",
             "-crf:1",
             "18",
             "-c:2",
             "libx264",
             "-crf:2",
             "28",
             "-f",
             "matroska",
             "-t",
             "0.5",
             "qualities.mkv"
           ]
  end

  test "decoder updates preserve references and stay with reordered input declarations" do
    first = Command.input("same.mkv", ss: 1)
    first_video = first[video: 0]
    second = Command.input("same.mkv")

    first = %{
      first
      | decoders: %{{:video, 0} => %Decoder{name: "h264", options: [{"threads", 2}]}}
    }

    second = %{
      second
      | decoders: %{{:video, 0} => %Decoder{options: [{"skip_frame", "nokey"}]}}
    }

    command =
      Command.new(
        inputs: [second, first],
        outputs: [Command.output([first_video, second[video: 0]], "out.mkv")]
      )

    assert Command.to_argv(command) == [
             "ffmpeg",
             "-skip_frame:v:0",
             "nokey",
             "-i",
             "same.mkv",
             "-ss",
             "1",
             "-c:v:0",
             "h264",
             "-threads:v:0",
             "2",
             "-i",
             "same.mkv",
             "-map",
             "1:v:0",
             "-map",
             "0:v:0",
             "out.mkv"
           ]
  end

  test "decoder bindings serialize deterministically with local media indexes" do
    input = Command.input("recording.mkv")

    input = %{
      input
      | decoders: %{
          {:video, 0} => %Decoder{name: "h264"},
          {:audio, 1} => %Decoder{name: "ac3", options: [{"drc_scale", 0.0}]},
          {:audio, 0} => %Decoder{name: "ac3", options: [{"drc_scale", 1.0}]}
        }
    }

    command = %Command{
      inputs: [input],
      outputs: [Command.output(input[:input], "out.mkv")]
    }

    assert Command.to_argv(command) == [
             "ffmpeg",
             "-c:a:0",
             "ac3",
             "-drc_scale:a:0",
             "1",
             "-c:a:1",
             "ac3",
             "-drc_scale:a:1",
             "0",
             "-c:v:0",
             "h264",
             "-i",
             "recording.mkv",
             "-map",
             "0",
             "out.mkv"
           ]
  end

  test "automatic selection emits only supplied AVOptions and keeps booleans valued" do
    input = Command.input("source.mkv")
    input = %{input | decoders: %{{:video, 0} => %Decoder{options: [threads: 2]}}}

    output = %Output{
      target: "out.mp4",
      mappings: [
        %Mapping{
          source: input[video: 0],
          encoding: %Encoder{
            options: [
              preset: :slow,
              crf: 18.5,
              fastfirstpass: true,
              a53cc: false,
              "x264-params": "keyint=24:scenecut=0"
            ]
          }
        }
      ],
      muxer: %Muxer{options: [empty_hdlr_name: true, movflags: "faststart+use_metadata_tags"]},
      options: [shortest: true]
    }

    command = %Command{global_options: [y: true], inputs: [input], outputs: [output]}

    assert Command.to_argv(command) == [
             "ffmpeg",
             "-y",
             "-threads:v:0",
             "2",
             "-i",
             "source.mkv",
             "-map",
             "0:v:0",
             "-preset:0",
             "slow",
             "-crf:0",
             "18.5",
             "-fastfirstpass:0",
             "true",
             "-a53cc:0",
             "false",
             "-x264-params:0",
             "keyint=24:scenecut=0",
             "-empty_hdlr_name",
             "true",
             "-movflags",
             "faststart+use_metadata_tags",
             "-shortest",
             "out.mp4"
           ]
  end

  test "empty component configurations do not emit invented defaults" do
    input = Command.input("source.mkv")
    input = %{input | decoders: %{{:video, 0} => %Decoder{}}}

    output = %Output{
      target: "out.mp4",
      mappings: [%Mapping{source: input[video: 0], encoding: %Encoder{}}],
      muxer: %Muxer{}
    }

    command = %Command{inputs: [input], outputs: [output]}
    assert Command.to_argv(command) == ["ffmpeg", "-i", "source.mkv", "-map", "0:v:0", "out.mp4"]
  end

  test "configuration names are literal values, not live discovery requests" do
    input = Command.input("source.mkv")

    output = %Output{
      target: "out.file",
      mappings: [
        %Mapping{source: input[video: 0], encoding: %Encoder{name: "not_installed;encoder"}}
      ],
      muxer: %Muxer{name: "not_installed_muxer"}
    }

    command = %Command{inputs: [input], outputs: [output]}

    assert Command.to_argv(command) == [
             "ffmpeg",
             "-i",
             "source.mkv",
             "-map",
             "0:v:0",
             "-c:0",
             "not_installed;encoder",
             "-f",
             "not_installed_muxer",
             "out.file"
           ]
  end

  test "reordering mappings and reusing encoders resets indexes for each output" do
    input = Command.input("source.mkv")
    encoder = %Encoder{name: "libx264", options: [crf: 18]}
    video = %Mapping{source: input[video: 0], encoding: encoder}
    audio = %Mapping{source: input[audio: 0], encoding: :copy}

    first = %Output{
      target: "first.mp4",
      mappings: [audio, video],
      muxer: %Muxer{name: "mp4", options: [movflags: "faststart"]}
    }

    second = %Output{
      target: "second.mkv",
      mappings: [video, audio],
      muxer: %Muxer{name: "matroska"}
    }

    command = %Command{inputs: [input], outputs: [first, second]}

    assert Command.to_argv(command) == [
             "ffmpeg",
             "-i",
             "source.mkv",
             "-map",
             "0:a:0",
             "-map",
             "0:v:0",
             "-c:0",
             "copy",
             "-c:1",
             "libx264",
             "-crf:1",
             "18",
             "-f",
             "mp4",
             "-movflags",
             "faststart",
             "first.mp4",
             "-map",
             "0:v:0",
             "-map",
             "0:a:0",
             "-c:0",
             "libx264",
             "-crf:0",
             "18",
             "-c:1",
             "copy",
             "-f",
             "matroska",
             "second.mkv"
           ]
  end

  test "callbacks retain input configuration and accept configured graph exports" do
    input = Command.input("source.mkv")
    input = %{input | decoders: %{{:video, 0} => %Decoder{name: "h264"}}}

    command =
      FFix.command(
        [source: input],
        fn inputs ->
          %{
            video: Filter.scale(inputs[:source][video: 0], w: 320, h: -1),
            audio: inputs[:source][audio: 0]
          }
        end,
        fn exports, inputs ->
          assert inputs[:source].decoders == input.decoders

          FFix.output(
            [
              %Mapping{source: exports.video, encoding: %Encoder{name: "libx264"}},
              %Mapping{source: exports.audio, encoding: :copy}
            ],
            "out.mkv"
          )
        end
      )

    assert Command.to_argv(command) == [
             "ffmpeg",
             "-c:v:0",
             "h264",
             "-i",
             "source.mkv",
             "-filter_complex",
             "[0:v:0]scale=w=320:h=-1[video];",
             "-map",
             "[video]",
             "-map",
             "0:a:0",
             "-c:0",
             "libx264",
             "-c:1",
             "copy",
             "out.mkv"
           ]
  end

  test "unconfigured broad mappings retain raw codec options with a structured muxer" do
    input = Command.input("source.mkv")
    output = Command.output(input[:input], "out.mkv", c: :copy)
    output = %{output | muxer: %Muxer{name: "matroska"}}
    command = %Command{inputs: [input], outputs: [output]}

    assert Command.to_argv(command) == [
             "ffmpeg",
             "-i",
             "source.mkv",
             "-map",
             "0",
             "-f",
             "matroska",
             "-c",
             "copy",
             "out.mkv"
           ]
  end

  test "configured outputs reject broad or raw selectors even in unconfigured mappings" do
    input = Command.input("source.mkv")

    for selector <- [:input, :video, :audio, {:raw, "a:0?"}, {:raw, "v:0"}] do
      output = %Output{
        target: "out.mkv",
        mappings: [
          %Mapping{source: input[video: 0], encoding: %Encoder{name: "libx264"}},
          %Mapping{source: input[selector]}
        ]
      }

      command = %Command{inputs: [input], outputs: [output]}

      assert_raise ArgumentError, ~r/every output mapping to select one stream/, fn ->
        Command.to_argv(command)
      end
    end
  end

  test "a graph export of a broad input is not mistaken for one filtered stream" do
    input = Command.input("source.mkv")
    graph = FFix.graph(outputs: [audio: input[:audio]])
    mapping = %Mapping{source: graph[:audio], encoding: :copy}

    command = %Command{
      inputs: [input],
      graph: graph,
      outputs: [Command.output(mapping, "out.mka")]
    }

    assert_raise ArgumentError, ~r/every output mapping to select one stream/, fn ->
      Command.to_argv(command)
    end
  end

  test "copy rejects actual filter outputs including export shorthands" do
    input = Command.input("source.mkv")
    graph = FFix.graph(outputs: [video: Filter.scale(input[video: 0], w: 320, h: -1)])

    for source <- [graph[:video], :video, 0] do
      command = %Command{
        inputs: [input],
        graph: graph,
        outputs: [Command.output(%Mapping{source: source, encoding: :copy}, "out.mkv")]
      }

      assert_raise ArgumentError, "cannot copy a filtered source; use an encoder", fn ->
        Command.to_argv(command)
      end
    end
  end

  test "structured decoding requires indexed selectors and decoder values" do
    input = Command.input("source.mkv")
    output = Command.output(input[video: 0], "out.mkv")

    for selector <- [:video, :input, {:raw, "v:0"}, {:audio, -1}, {:video, 1.5}] do
      configured = %{input | decoders: %{selector => %Decoder{name: "h264"}}}
      command = %Command{inputs: [configured], outputs: [output]}

      assert_raise ArgumentError, ~r/decoder selector must be/, fn ->
        Command.to_argv(command)
      end
    end

    configured = %{input | decoders: %{{:video, 0} => %Encoder{name: "libx264"}}}
    command = %Command{inputs: [configured], outputs: [output]}

    assert_raise ArgumentError, ~r/invalid decoder configuration/, fn ->
      Command.to_argv(command)
    end
  end

  test "raw codec selections and matching AVOptions cannot override structured encoding" do
    input = Command.input("source.mkv")
    encoder = %Encoder{name: "libx264", options: [crf: 18]}
    mapping = %Mapping{source: input[video: 0], encoding: encoder}

    for option <- [{"c:v", "copy"}, {:vcodec, "copy"}, {"codec:0", "copy"}, {"crf:0", 28}] do
      output = Command.output(mapping, "out.mkv", [option])
      command = %Command{inputs: [input], outputs: [output]}

      assert_raise ArgumentError, ~r/cannot be combined with structured encoding/, fn ->
        Command.to_argv(command)
      end
    end
  end

  test "raw bitrate aliases cannot override structured encoding" do
    input = Command.input("source.mkv")
    encoder = %Encoder{name: "aac", options: [b: "128k"]}
    mapping = %Mapping{source: input[audio: 0], encoding: encoder}

    for name <- ["ab", "vb"] do
      output = Command.output(mapping, "out.mkv", [{name, "64k"}])
      command = %Command{inputs: [input], outputs: [output]}

      assert_raise ArgumentError, ~r/cannot be combined with structured encoding/, fn ->
        Command.to_argv(command)
      end
    end
  end

  test "raw input codec options cannot override structured decoding" do
    for option <- [{"c:v", "hevc"}, {"threads:v:0", 8}] do
      input = Command.input("source.mkv", [option])
      input = %{input | decoders: %{{:video, 0} => %Decoder{options: [threads: 2]}}}
      output = Command.output(input[video: 0], "out.mkv")
      command = %Command{inputs: [input], outputs: [output]}

      assert_raise ArgumentError, ~r/cannot be combined with structured decoding/, fn ->
        Command.to_argv(command)
      end
    end
  end

  test "raw format selections and matching options cannot override a structured muxer" do
    input = Command.input("source.mkv")

    for option <- [{:f, :matroska}, {:movflags, "frag_keyframe"}] do
      output = %Output{
        target: "out.mp4",
        mappings: [%Mapping{source: input[video: 0]}],
        muxer: %Muxer{name: "mp4", options: [movflags: "faststart"]},
        options: [option]
      }

      command = %Command{inputs: [input], outputs: [output]}

      assert_raise ArgumentError, ~r/cannot be combined with a structured muxer/, fn ->
        Command.to_argv(command)
      end
    end
  end

  test "raw mapping changes cannot invalidate generated output-stream indexes" do
    input = Command.input("source.mkv")
    mapping = %Mapping{source: input[video: 0], encoding: :copy}

    for option <- [{:map, "0:a"}, {:vn, true}, {:an, true}, {:attach, "cover.jpg"}] do
      command = %Command{
        inputs: [input],
        outputs: [Command.output(mapping, "out.mkv", [option])]
      }

      assert_raise ArgumentError, ~r/cannot be combined with structured encoding/, fn ->
        Command.to_argv(command)
      end
    end
  end

  test "raw extra inputs and filtergraphs cannot shift configured mapping indexes" do
    input = Command.input("source.mkv")
    output = Command.output(%Mapping{source: input[video: 0], encoding: :copy}, "out.mkv")

    for options <- [[i: "other.mkv"], [filter_complex: "color"]] do
      global_command = %Command{global_options: options, inputs: [input], outputs: [output]}
      input_command = %Command{inputs: [%{input | options: options}], outputs: [output]}

      for command <- [global_command, input_command] do
        assert_raise ArgumentError, ~r/cannot be combined with configured mappings/, fn ->
          Command.to_argv(command)
        end
      end
    end
  end

  test "component options reject pre-scoped keys, CLI controls, and ambiguous values" do
    input = Command.input("source.mkv")

    for options <- [
          [{"crf:v:0", 18}],
          [{"-crf", 18}],
          [{"", 18}],
          [{:c, "copy"}],
          [{:map, "0:a"}],
          [{:crf, nil}],
          [{:flags, [:fast]}],
          [{:crf, %{value: 18}}],
          [12],
          %{crf: 18}
        ] do
      encoder = %Encoder{name: "libx264", options: options}
      output = Command.output(%Mapping{source: input[video: 0], encoding: encoder}, "out.mkv")
      command = %Command{inputs: [input], outputs: [output]}

      assert_raise ArgumentError, fn -> Command.to_argv(command) end
    end
  end

  test "copy cannot be disguised as an encoder" do
    input = Command.input("source.mkv")
    mapping = %Mapping{source: input[video: 0], encoding: %Encoder{name: "copy"}}
    command = %Command{inputs: [input], outputs: [Command.output(mapping, "out.mkv")]}

    assert_raise ArgumentError, "copy is a mapping mode; use encoding: :copy", fn ->
      Command.to_argv(command)
    end
  end
end
