defmodule FFix.Discovery.ParserTest do
  use ExUnit.Case, async: true

  alias FFix.Discovery.Error
  alias FFix.Discovery.Parser

  @fixtures Path.expand("../../fixtures/discovery/ffmpeg-7.1.5", __DIR__)

  test "codec registries distinguish implementations from codec formats" do
    assert {:ok, encoders} = Parser.list(:encoder, fixture("encoders"))
    encoder = named(encoders, "libx264")
    assert encoder.media_type == :video
    assert encoder.codec == "h264"
    assert encoder.flags == "V....D"

    assert {:ok, decoders} = Parser.list(:decoder, fixture("decoders"))
    assert named(decoders, "ass").media_type == :subtitle

    assert {:ok, codecs} = Parser.list(:codec, fixture("codecs"))
    assert "libx264" in named(codecs, "h264").encoders
    assert "h264" in named(codecs, "h264").decoders
  end

  test "format aliases stay scoped by direction, including combined catalogs" do
    assert {:ok, muxers} = Parser.list(:muxer, fixture("muxers"))
    assert named(muxers, "mp4").names == ["mp4"]
    assert named(muxers, "mov").names == ["mov"]

    assert {:ok, demuxers} = Parser.list(:demuxer, fixture("demuxers"))
    assert named(demuxers, "mp4").names == ~w(mov mp4 m4a 3gp 3g2 mj2)

    duplicate_alias = fixture("demuxers") <> " D   mp4 Duplicate input alias\n"
    assert {:error, %Error{reason: :invalid_output}} = Parser.list(:demuxer, duplicate_alias)

    assert {:ok, formats} = Parser.list(:format, fixture("formats"))
    assert Enum.count(formats, &("mp4" in &1.names)) == 2

    assert {:ok, devices} = Parser.list(:device, fixture("devices"))
    assert named(devices, "libcdio").description == ""
    assert named(devices, "alsa").directions == [:input, :output]
    assert named(devices, "v4l2").names == ["video4linux2", "v4l2"]
    assert Enum.all?(devices, & &1.device?)
  end

  test "older format flag columns and unknown flags retain their spelling" do
    text =
      "File formats:\n D. = Demuxing supported\n .E = Muxing supported\n --\n D  mov,mp4 QuickTime\n"

    assert {:ok, [entry]} = Parser.list(:demuxer, text)
    assert entry.flags == "D "
    assert entry.names == ["mov", "mp4"]
    assert entry.device? == nil

    text = "Encoders:\n ------\n V....Z future-codec Description\n"
    assert {:ok, [%{flags: "V....Z", names: ["future-codec"]}]} = Parser.list(:encoder, text)
  end

  test "filter registries preserve dynamic and source pad signatures" do
    assert {:ok, filters} = Parser.list(:filter, fixture("filters"))
    assert named(filters, "overlay").inputs == "VV"
    assert named(filters, "split").outputs == "N"
    assert named(filters, "nullsrc").inputs == "|"
  end

  test "protocol directions merge without losing order; simple catalogs remain simple" do
    text = "Supported file protocols:\nInput:\n  file\n  http\nOutput:\n  file\n  md5\n"
    assert {:ok, [file, http, md5]} = Parser.list(:protocol, text)
    assert file == %{kind: :protocol, names: ["file"], directions: [:input, :output]}
    assert http.directions == [:input]
    assert md5.directions == [:output]

    for {kind, text, name} <- [
          {:bitstream_filter, "Bitstream filters:\nnull\n", "null"},
          {:hardware_acceleration, "Hardware acceleration methods:\ncuda\n", "cuda"},
          {:disposition, "default\n", "default"}
        ] do
      assert {:ok, [%{kind: ^kind, names: [^name]}]} = Parser.list(kind, text)
    end

    assert {:ok, []} = Parser.list(:hardware_acceleration, "Hardware acceleration methods:\n")
    assert {:ok, [%{rgb: "#f0f8ff"}]} = Parser.list(:color, "name  #RRGGBB\nAliceBlue  #f0f8ff\n")
  end

  test "raw media catalogs preserve declared values, including hardware formats" do
    assert {:ok, pixels} = Parser.list(:pixel_format, fixture("pix_fmts"))
    assert named(pixels, "yuv420p").bit_depths == [8, 8, 8]
    assert named(pixels, "yuv420p").bits_per_pixel == 12
    assert named(pixels, "cuda").components == 0

    assert {:ok, samples} = Parser.list(:sample_format, fixture("sample_fmts"))
    assert named(samples, "s16p").bit_depth == 16

    assert {:ok, channels} = Parser.list(:channel, fixture("layouts"))
    assert named(channels, "FL").description == "front left"
    assert {:ok, layouts} = Parser.list(:channel_layout, fixture("layouts"))
    assert named(layouts, "stereo").decomposition == "FL+FR"

    older = "Pixel formats:\n-----\nIO... yuv420p 3 12\n"
    assert {:ok, [%{bit_depths: nil}]} = Parser.list(:pixel_format, older)
  end

  test "codec help preserves reported properties and array options" do
    assert {:ok, help} = Parser.help(:encoder, fixture("encoder-libx264"))
    assert help.names == ["libx264"]
    assert {"Threading capabilities", "other"} in help.properties
    assert [section] = help.option_sections
    assert option(section, "preset").declared_default == ~s("medium")
    assert option(section, "crf").ranges == [%{min: "-1", max: "FLT_MAX"}]

    assert {:ok, help} = Parser.help(:decoder, fixture("decoder-hevc"))
    assert [section] = help.option_sections
    assert option(section, "view_ids").type == {:array, :int}
    assert option(section, "view_ids_available").type == {:array, :unsigned}
    assert option(section, "view_ids_available").flags == ".D.V..XR..."
  end

  test "filter help keeps separate option owners and pad identity" do
    assert {:ok, help} = Parser.help(:filter, fixture("filter-overlay"))
    assert [%{name: "overlay"} = overlay, %{name: "framesync"} = framesync] = help.option_sections
    assert Enum.map(help.inputs, & &1.name) == ["main", "overlay"]
    assert help.outputs == [%{index: 0, name: "default", media_type: "video"}]
    assert option(overlay, "eof_action").constants |> Enum.map(& &1.value) == ["0", "1", "2"]
    assert option(framesync, "eof_action").declared_default == "repeat"
    assert Enum.any?(help.notes, &String.contains?(&1, "timeline"))

    assert {:ok, split} = Parser.help(:filter, fixture("filter-split"))
    assert split.outputs == %{dynamic: "dynamic (depending on the options)"}
  end

  test "constant names can contain spaces without swallowing their value columns" do
    assert {:ok, help} = Parser.help(:filter, fixture("filter-afireqsrc"))
    assert help.inputs == []
    assert [section] = help.option_sections
    constants = option(section, "preset").constants
    assert Enum.find(constants, &(&1.name == "deep bass")).value == "6"
    assert Enum.find(constants, &(&1.name == "vocal booster")).value == "17"

    text =
      "  -flags <flags> E..........\n    long-constant-name 1e+02 E..........\n    slow but steady E..........\n"

    assert {:ok, [%{constants: [number, flag]}]} = Parser.options(text)
    assert number.name == "long-constant-name"
    assert number.value == "1e+02"
    assert flag.name == "slow but steady"
    assert flag.value == nil

    assert {:error, %Error{line: 2}} =
             Parser.options("  -good <int> E..........\n  -broken <int E...........")
  end

  test "format and transport help share options without conflating class names and aliases" do
    assert {:ok, muxer} = Parser.help(:muxer, fixture("muxer-mp4"))
    assert muxer.names == ["mp4"]
    assert {"Default video codec", "h264."} in muxer.properties
    assert [section] = muxer.option_sections
    faststart = Enum.find(option(section, "movflags").constants, &(&1.name == "faststart"))
    assert faststart.value == nil

    assert {:ok, demuxer} = Parser.help(:demuxer, fixture("demuxer-mov"))
    assert demuxer.names == ~w(mov mp4 m4a 3gp 3g2 mj2)
    assert {:ok, protocol} = Parser.help(:protocol, fixture("protocol-http"))
    assert protocol.names == []
    assert [%{name: "http"} | _] = protocol.option_sections
    assert {:ok, bsf} = Parser.help(:bitstream_filter, fixture("bsf-aac_adtstoasc"))
    assert bsf.names == ["aac_adtstoasc"]
  end

  test "empty options, unavailable help, and multi-implementation help are distinct" do
    assert {:ok, %{option_sections: []}} = Parser.help(:decoder, fixture("decoder-ass"))

    assert {:error, %Error{reason: :help_unavailable}} =
             Parser.help(:protocol, "Unknown protocol 'md5'.\n")

    text = fixture("encoder-libx264") <> "Encoder other [Another implementation]:\n"
    assert {:error, %Error{reason: :invalid_output}} = Parser.help(:encoder, text)
    assert {:error, %Error{reason: :invalid_output}} = Parser.help(:decoder, "")
  end

  test "option parsing tolerates new vocabulary, punctuation, and CRLF without atomizing names" do
    text = "  -future-name <future_type> E..V......Z UTF-8: µ → ° (default \"\")\r\n"
    assert {:ok, [option]} = Parser.options(text)
    assert option.name == "future-name"
    assert option.type == {:unknown, "future_type"}
    assert option.flags == "E..V......Z"
    assert option.declared_default == ~s("")
    assert option.help == ~s|UTF-8: µ → ° (default "")|
  end

  test "only terminal default/range annotations are extracted and help stays intact" do
    for {help, default, ranges} <- [
          {~s|example (default 1) in prose|, nil, []},
          {~s|text (default "a (b)")|, ~s|"a (b)"|, []},
          {~s|text (from -1 to INT_MAX) (default auto)|, "auto", [%{min: "-1", max: "INT_MAX"}]},
          {~s|(from 0 to 1)|, nil, [%{min: "0", max: "1"}]}
        ] do
      assert {:ok, [option]} = Parser.options("  -value <string> E.......... " <> help)
      assert option.declared_default == default
      assert option.ranges == ranges
      assert option.help == help
    end
  end

  test "malformed rows and orphan constants report their original line instead of disappearing" do
    for row <- [
          "  -broken <int E.......... description",
          "  orphan 1 E.......... description",
          "  -value <int> E.."
        ] do
      text = "Decoder example [Example]:\nexample AVOptions:\n" <> row
      assert {:error, %Error{line: 3, text: ^row}} = Parser.help(:decoder, text)
    end

    assert {:error, %Error{line: 3}} =
             Parser.list(:encoder, "Encoders:\n ------\n V.... truncated")

    assert {:error, %Error{}} = Parser.list(:sample_format, "not a catalog")
    assert {:error, %Error{}} = Parser.list(:disposition, "default\ndefault\n")
  end

  test "shared sections exclude neighboring private classes" do
    assert {:ok, sections} = Parser.shared(fixture("shared-excerpt"))
    assert Enum.map(sections, & &1.name) == ~w(AVFormatContext AVIOContext URLContext)
    assert option(hd(sections), "probesize").type == :int64
    assert {:error, %Error{}} = Parser.shared("private AVOptions:\n  -value <int> E..........\n")
  end

  test "version provenance does not require semantic versioning" do
    raw = fixture("version")
    assert {:ok, version} = Parser.version(raw)
    assert version.version == "7.1.5"
    assert version.raw == raw
    assert version.configuration =~ "--enable-shared"
    assert List.keymember?(version.libraries, "libavcodec", 0)

    assert {:ok, %{version: "N-custom-build"}} =
             Parser.version("ffmpeg version N-custom-build Copyright\n")
  end

  defp fixture(name), do: File.read!(Path.join(@fixtures, name <> ".txt"))
  defp named(entries, name), do: Enum.find(entries, &(name in &1.names))
  defp option(section, name), do: Enum.find(section.options, &(&1.name == name))
end
