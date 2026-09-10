defmodule FFix.Decoder do
  @moduledoc """
  Decoder shortcuts that configure streams on an input declaration.

  Named helpers return an updated `FFix.Command.Input`, preserving its identity.
  Their short form selects the first stream of the decoder's media type. Pass
  an indexed selector and options explicitly to configure another stream.

      input
      |> FFix.Decoder.h264({:video, 0}, threads: 2)
      |> FFix.Decoder.aac(threads: 1)

  All decoded uses of an input stream share its configuration. Independent
  decoding requires separate input declarations, even for the same source file.
  Decoder helpers do not operate on individual filter branches. Pass the updated
  input into the command: changing a callback-local input does not mutate the
  command's existing input declaration.

  Named helpers check options against recorded metadata without querying FFmpeg.
  Reported defaults are not emitted, strings remain open FFmpeg values, and
  `raw: [{"new_option", "value"}]` bypasses metadata checks for particular options.
  Registration in the baseline does not guarantee availability in another build.

  `named/4` is the dynamic-name escape hatch. `auto/3` leaves decoder selection to
  FFmpeg. `new/2` constructs an unbound configuration for the lower-level model.
  """

  alias FFix.Command
  alias FFix.Command.Input
  alias FFix.Options

  @type t :: %__MODULE__{name: String.t() | nil, options: [Command.av_option()]}
  defstruct [:name, options: []]

  @doc "Builds an unbound configuration without metadata lookup."
  @spec new(String.t() | nil, [Command.av_option()]) :: t()
  def new(name, options \\ []) do
    Command.validate_component!(%__MODULE__{name: name, options: options})
  end

  @doc "Configures one indexed input stream using a dynamic decoder name."
  @spec named(Input.t(), Input.decoder_selector(), String.t() | nil, list()) :: Input.t()
  def named(input, selector, name, options \\ []) do
    unless is_struct(input, Input) do
      raise ArgumentError, "decoder configuration expects an input declaration, not a stream"
    end

    options = Options.normalize!(options, nil, "#{name || "automatic"} decoder")
    decoder = new(name, options)
    Command.validate_decoder!(selector, decoder)
    %{input | decoders: Map.put(input.decoders, selector, decoder)}
  end

  @doc "Configures one indexed input stream without forcing a decoder implementation."
  @spec auto(Input.t(), Input.decoder_selector(), list()) :: Input.t()
  def auto(input, selector, options \\ []), do: named(input, selector, nil, options)

  defp check_media!(selector, media) do
    case selector do
      {^media, _index} ->
        :ok

      _other ->
        raise ArgumentError, "expected an indexed #{media} selector, got: #{inspect(selector)}"
    end
  end

  # BEGIN GENERATED HELPERS
  @h264_schema %{
    "enable_er" => [%{type: :boolean, constants: []}],
    "err_detect" => [
      %{
        type: :flags,
        constants: [
          "crccheck",
          "bitstream",
          "buffer",
          "explode",
          "ignore_err",
          "careful",
          "compliant",
          "aggressive"
        ]
      }
    ],
    "flags" => [
      %{
        type: :flags,
        constants: [
          "unaligned",
          "mv4",
          "qpel",
          "loop",
          "gray",
          "psnr",
          "ildct",
          "low_delay",
          "global_header",
          "bitexact",
          "aic",
          "ilme",
          "cgop",
          "output_corrupt",
          "drop_changed"
        ]
      }
    ],
    "flags2" => [
      %{
        type: :flags,
        constants: [
          "fast",
          "noout",
          "ignorecrop",
          "local_header",
          "chunks",
          "showall",
          "export_mvs",
          "skip_manual",
          "ass_ro_flush_noop",
          "icc_profiles"
        ]
      }
    ],
    "is_avc" => [%{type: :boolean, constants: []}],
    "lowres" => [%{type: :int, constants: []}],
    "nal_length_size" => [%{type: :int, constants: []}],
    "noref_gray" => [%{type: :boolean, constants: []}],
    "skip_frame" => [
      %{type: :int, constants: ["none", "default", "noref", "bidir", "nointra", "nokey", "all"]}
    ],
    "skip_gray" => [%{type: :boolean, constants: []}],
    "skip_idct" => [
      %{type: :int, constants: ["none", "default", "noref", "bidir", "nointra", "nokey", "all"]}
    ],
    "skip_loop_filter" => [
      %{type: :int, constants: ["none", "default", "noref", "bidir", "nointra", "nokey", "all"]}
    ],
    "strict" => [
      %{type: :int, constants: ["very", "strict", "normal", "unofficial", "experimental"]}
    ],
    "thread_type" => [%{type: :flags, constants: ["slice", "frame"]}],
    "threads" => [%{type: :int, constants: ["auto"]}],
    "x264_build" => [%{type: :int, constants: []}]
  }
  @type h264_option ::
          {:enable_er, boolean() | :auto | String.t()}
          | {:err_detect,
             integer()
             | String.t()
             | [
                 String.t()
                 | :crccheck
                 | :bitstream
                 | :buffer
                 | :explode
                 | :ignore_err
                 | :careful
                 | :compliant
                 | :aggressive
               ]
             | :crccheck
             | :bitstream
             | :buffer
             | :explode
             | :ignore_err
             | :careful
             | :compliant
             | :aggressive}
          | {:flags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :unaligned
                 | :mv4
                 | :qpel
                 | :loop
                 | :gray
                 | :psnr
                 | :ildct
                 | :low_delay
                 | :global_header
                 | :bitexact
                 | :aic
                 | :ilme
                 | :cgop
                 | :output_corrupt
                 | :drop_changed
               ]
             | :unaligned
             | :mv4
             | :qpel
             | :loop
             | :gray
             | :psnr
             | :ildct
             | :low_delay
             | :global_header
             | :bitexact
             | :aic
             | :ilme
             | :cgop
             | :output_corrupt
             | :drop_changed}
          | {:flags2,
             integer()
             | String.t()
             | [
                 String.t()
                 | :fast
                 | :noout
                 | :ignorecrop
                 | :local_header
                 | :chunks
                 | :showall
                 | :export_mvs
                 | :skip_manual
                 | :ass_ro_flush_noop
                 | :icc_profiles
               ]
             | :fast
             | :noout
             | :ignorecrop
             | :local_header
             | :chunks
             | :showall
             | :export_mvs
             | :skip_manual
             | :ass_ro_flush_noop
             | :icc_profiles}
          | {:is_avc, boolean() | :auto | String.t()}
          | {:lowres, integer() | String.t()}
          | {:nal_length_size, integer() | String.t()}
          | {:noref_gray, boolean() | :auto | String.t()}
          | {:skip_frame,
             integer()
             | String.t()
             | :none
             | :default
             | :noref
             | :bidir
             | :nointra
             | :nokey
             | :all}
          | {:skip_gray, boolean() | :auto | String.t()}
          | {:skip_idct,
             integer()
             | String.t()
             | :none
             | :default
             | :noref
             | :bidir
             | :nointra
             | :nokey
             | :all}
          | {:skip_loop_filter,
             integer()
             | String.t()
             | :none
             | :default
             | :noref
             | :bidir
             | :nointra
             | :nokey
             | :all}
          | {:strict,
             integer() | String.t() | :very | :strict | :normal | :unofficial | :experimental}
          | {:thread_type,
             integer() | String.t() | [String.t() | :slice | :frame] | :slice | :frame}
          | {:threads, integer() | String.t() | :auto}
          | {:x264_build, integer() | String.t()}
          | {:raw, [Command.av_option()]}
  @doc """
  h264: H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10

  Configures the first video stream; use the three-argument form for another index.

    * General capabilities: dr1 delay threads
    * Threading capabilities: frame and slice
    * Supported hardware devices: cuda vaapi vdpau vulkan

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `is_avc` (H264 Decoder, :boolean): is avc (default false)
    * `nal_length_size` (H264 Decoder, :int): nal_length_size (from 0 to 4) (default 0)
    * `enable_er` (H264 Decoder, :boolean): Enable error resilience on damaged frames (unsafe) (default auto)
    * `x264_build` (H264 Decoder, :int): Assume this x264 version if no x264 version found in any SEI (from -1 to INT_MAX) (default -1)
    * `skip_gray` (H264 Decoder, :boolean): Do not return gray gap frames (default false)
    * `noref_gray` (H264 Decoder, :boolean): Avoid using gray gap frames as references (default true)
    * `flags` (AVCodecContext, :flags): (default 0) Reported constants: unaligned, mv4, qpel, loop, gray, psnr, ildct, low_delay, global_header, bitexact, aic, ilme, cgop, output_corrupt, drop_changed.
    * `flags2` (AVCodecContext, :flags): (default 0) Reported constants: fast, noout, ignorecrop, local_header, chunks, showall, export_mvs, skip_manual, ass_ro_flush_noop, icc_profiles.
    * `strict` (AVCodecContext, :int): how strictly to follow the standards (from INT_MIN to INT_MAX) (default normal) Reported constants: very, strict, normal, unofficial, experimental.
    * `err_detect` (AVCodecContext, :flags): set error detection flags (default 0) Reported constants: crccheck, bitstream, buffer, explode, ignore_err, careful, compliant, aggressive.
    * `threads` (AVCodecContext, :int): set the number of threads (from 0 to INT_MAX) (default 1) Reported constants: auto.
    * `lowres` (AVCodecContext, :int): decode at 1= 1/2, 2=1/4, 3=1/8 resolutions (from 0 to INT_MAX) (default 0)
    * `skip_loop_filter` (AVCodecContext, :int): skip loop filtering process for the selected frames (from INT_MIN to INT_MAX) (default default) Reported constants: none, default, noref, bidir, nointra, nokey, all.
    * `skip_idct` (AVCodecContext, :int): skip IDCT/dequantization for the selected frames (from INT_MIN to INT_MAX) (default default) Reported constants: none, default, noref, bidir, nointra, nokey, all.
    * `skip_frame` (AVCodecContext, :int): skip decoding for the selected frames (from INT_MIN to INT_MAX) (default default) Reported constants: none, default, noref, bidir, nointra, nokey, all.
    * `thread_type` (AVCodecContext, :flags): select multithreading type (default slice+frame) Reported constants: slice, frame.
  """
  @spec h264(Input.t(), [h264_option()]) :: Input.t()
  def h264(input, options \\ []), do: h264(input, {:video, 0}, options)

  @doc "Configures an explicitly indexed input stream. See `h264/2` for options."
  @spec h264(Input.t(), Input.decoder_selector(), [h264_option()]) :: Input.t()
  def h264(input, selector, options) do
    check_media!(selector, :video)
    options = Options.normalize!(options, @h264_schema, "h264 decoder")
    named(input, selector, "h264", options)
  end

  @hevc_schema %{
    "apply_defdispwin" => [%{type: :boolean, constants: []}],
    "err_detect" => [
      %{
        type: :flags,
        constants: [
          "crccheck",
          "bitstream",
          "buffer",
          "explode",
          "ignore_err",
          "careful",
          "compliant",
          "aggressive"
        ]
      }
    ],
    "flags" => [
      %{
        type: :flags,
        constants: [
          "unaligned",
          "mv4",
          "qpel",
          "loop",
          "gray",
          "psnr",
          "ildct",
          "low_delay",
          "global_header",
          "bitexact",
          "aic",
          "ilme",
          "cgop",
          "output_corrupt",
          "drop_changed"
        ]
      }
    ],
    "flags2" => [
      %{
        type: :flags,
        constants: [
          "fast",
          "noout",
          "ignorecrop",
          "local_header",
          "chunks",
          "showall",
          "export_mvs",
          "skip_manual",
          "ass_ro_flush_noop",
          "icc_profiles"
        ]
      }
    ],
    "lowres" => [%{type: :int, constants: []}],
    "skip_frame" => [
      %{type: :int, constants: ["none", "default", "noref", "bidir", "nointra", "nokey", "all"]}
    ],
    "skip_idct" => [
      %{type: :int, constants: ["none", "default", "noref", "bidir", "nointra", "nokey", "all"]}
    ],
    "skip_loop_filter" => [
      %{type: :int, constants: ["none", "default", "noref", "bidir", "nointra", "nokey", "all"]}
    ],
    "strict" => [
      %{type: :int, constants: ["very", "strict", "normal", "unofficial", "experimental"]}
    ],
    "strict-displaywin" => [%{type: :boolean, constants: []}],
    "thread_type" => [%{type: :flags, constants: ["slice", "frame"]}],
    "threads" => [%{type: :int, constants: ["auto"]}],
    "view_ids" => [%{type: {:array, :int}, constants: []}]
  }
  @type hevc_option ::
          {:apply_defdispwin, boolean() | :auto | String.t()}
          | {:err_detect,
             integer()
             | String.t()
             | [
                 String.t()
                 | :crccheck
                 | :bitstream
                 | :buffer
                 | :explode
                 | :ignore_err
                 | :careful
                 | :compliant
                 | :aggressive
               ]
             | :crccheck
             | :bitstream
             | :buffer
             | :explode
             | :ignore_err
             | :careful
             | :compliant
             | :aggressive}
          | {:flags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :unaligned
                 | :mv4
                 | :qpel
                 | :loop
                 | :gray
                 | :psnr
                 | :ildct
                 | :low_delay
                 | :global_header
                 | :bitexact
                 | :aic
                 | :ilme
                 | :cgop
                 | :output_corrupt
                 | :drop_changed
               ]
             | :unaligned
             | :mv4
             | :qpel
             | :loop
             | :gray
             | :psnr
             | :ildct
             | :low_delay
             | :global_header
             | :bitexact
             | :aic
             | :ilme
             | :cgop
             | :output_corrupt
             | :drop_changed}
          | {:flags2,
             integer()
             | String.t()
             | [
                 String.t()
                 | :fast
                 | :noout
                 | :ignorecrop
                 | :local_header
                 | :chunks
                 | :showall
                 | :export_mvs
                 | :skip_manual
                 | :ass_ro_flush_noop
                 | :icc_profiles
               ]
             | :fast
             | :noout
             | :ignorecrop
             | :local_header
             | :chunks
             | :showall
             | :export_mvs
             | :skip_manual
             | :ass_ro_flush_noop
             | :icc_profiles}
          | {:lowres, integer() | String.t()}
          | {:skip_frame,
             integer()
             | String.t()
             | :none
             | :default
             | :noref
             | :bidir
             | :nointra
             | :nokey
             | :all}
          | {:skip_idct,
             integer()
             | String.t()
             | :none
             | :default
             | :noref
             | :bidir
             | :nointra
             | :nokey
             | :all}
          | {:skip_loop_filter,
             integer()
             | String.t()
             | :none
             | :default
             | :noref
             | :bidir
             | :nointra
             | :nokey
             | :all}
          | {:strict,
             integer() | String.t() | :very | :strict | :normal | :unofficial | :experimental}
          | {:"strict-displaywin", boolean() | :auto | String.t()}
          | {:thread_type,
             integer() | String.t() | [String.t() | :slice | :frame] | :slice | :frame}
          | {:threads, integer() | String.t() | :auto}
          | {:view_ids, String.t()}
          | {:raw, [Command.av_option()]}
  @doc """
  hevc: HEVC (High Efficiency Video Coding)

  Configures the first video stream; use the three-argument form for another index.

    * General capabilities: dr1 delay threads
    * Threading capabilities: frame and slice
    * Supported hardware devices: cuda vaapi vdpau vulkan

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `apply_defdispwin` (HEVC decoder, :boolean): Apply default display window from VUI (default false)
    * `strict-displaywin` (HEVC decoder, :boolean): stricly apply default display window size (default false)
    * `view_ids` (HEVC decoder, {:array, :int}): Array of view IDs that should be decoded and output; a single -1 to decode all views
    * `flags` (AVCodecContext, :flags): (default 0) Reported constants: unaligned, mv4, qpel, loop, gray, psnr, ildct, low_delay, global_header, bitexact, aic, ilme, cgop, output_corrupt, drop_changed.
    * `flags2` (AVCodecContext, :flags): (default 0) Reported constants: fast, noout, ignorecrop, local_header, chunks, showall, export_mvs, skip_manual, ass_ro_flush_noop, icc_profiles.
    * `strict` (AVCodecContext, :int): how strictly to follow the standards (from INT_MIN to INT_MAX) (default normal) Reported constants: very, strict, normal, unofficial, experimental.
    * `err_detect` (AVCodecContext, :flags): set error detection flags (default 0) Reported constants: crccheck, bitstream, buffer, explode, ignore_err, careful, compliant, aggressive.
    * `threads` (AVCodecContext, :int): set the number of threads (from 0 to INT_MAX) (default 1) Reported constants: auto.
    * `lowres` (AVCodecContext, :int): decode at 1= 1/2, 2=1/4, 3=1/8 resolutions (from 0 to INT_MAX) (default 0)
    * `skip_loop_filter` (AVCodecContext, :int): skip loop filtering process for the selected frames (from INT_MIN to INT_MAX) (default default) Reported constants: none, default, noref, bidir, nointra, nokey, all.
    * `skip_idct` (AVCodecContext, :int): skip IDCT/dequantization for the selected frames (from INT_MIN to INT_MAX) (default default) Reported constants: none, default, noref, bidir, nointra, nokey, all.
    * `skip_frame` (AVCodecContext, :int): skip decoding for the selected frames (from INT_MIN to INT_MAX) (default default) Reported constants: none, default, noref, bidir, nointra, nokey, all.
    * `thread_type` (AVCodecContext, :flags): select multithreading type (default slice+frame) Reported constants: slice, frame.
  """
  @spec hevc(Input.t(), [hevc_option()]) :: Input.t()
  def hevc(input, options \\ []), do: hevc(input, {:video, 0}, options)

  @doc "Configures an explicitly indexed input stream. See `hevc/2` for options."
  @spec hevc(Input.t(), Input.decoder_selector(), [hevc_option()]) :: Input.t()
  def hevc(input, selector, options) do
    check_media!(selector, :video)
    options = Options.normalize!(options, @hevc_schema, "hevc decoder")
    named(input, selector, "hevc", options)
  end

  @aac_schema %{
    "channel_order" => [%{type: :int, constants: ["default", "coded"]}],
    "dual_mono_mode" => [%{type: :int, constants: ["auto", "main", "sub", "both"]}],
    "err_detect" => [
      %{
        type: :flags,
        constants: [
          "crccheck",
          "bitstream",
          "buffer",
          "explode",
          "ignore_err",
          "careful",
          "compliant",
          "aggressive"
        ]
      }
    ],
    "flags" => [
      %{
        type: :flags,
        constants: [
          "unaligned",
          "mv4",
          "qpel",
          "loop",
          "gray",
          "psnr",
          "ildct",
          "low_delay",
          "global_header",
          "bitexact",
          "aic",
          "ilme",
          "cgop",
          "output_corrupt",
          "drop_changed"
        ]
      }
    ],
    "flags2" => [
      %{
        type: :flags,
        constants: [
          "fast",
          "noout",
          "ignorecrop",
          "local_header",
          "chunks",
          "showall",
          "export_mvs",
          "skip_manual",
          "ass_ro_flush_noop",
          "icc_profiles"
        ]
      }
    ],
    "lowres" => [%{type: :int, constants: []}],
    "strict" => [
      %{type: :int, constants: ["very", "strict", "normal", "unofficial", "experimental"]}
    ],
    "thread_type" => [%{type: :flags, constants: ["slice", "frame"]}],
    "threads" => [%{type: :int, constants: ["auto"]}]
  }
  @type aac_option ::
          {:channel_order, integer() | String.t() | :default | :coded}
          | {:dual_mono_mode, integer() | String.t() | :auto | :main | :sub | :both}
          | {:err_detect,
             integer()
             | String.t()
             | [
                 String.t()
                 | :crccheck
                 | :bitstream
                 | :buffer
                 | :explode
                 | :ignore_err
                 | :careful
                 | :compliant
                 | :aggressive
               ]
             | :crccheck
             | :bitstream
             | :buffer
             | :explode
             | :ignore_err
             | :careful
             | :compliant
             | :aggressive}
          | {:flags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :unaligned
                 | :mv4
                 | :qpel
                 | :loop
                 | :gray
                 | :psnr
                 | :ildct
                 | :low_delay
                 | :global_header
                 | :bitexact
                 | :aic
                 | :ilme
                 | :cgop
                 | :output_corrupt
                 | :drop_changed
               ]
             | :unaligned
             | :mv4
             | :qpel
             | :loop
             | :gray
             | :psnr
             | :ildct
             | :low_delay
             | :global_header
             | :bitexact
             | :aic
             | :ilme
             | :cgop
             | :output_corrupt
             | :drop_changed}
          | {:flags2,
             integer()
             | String.t()
             | [
                 String.t()
                 | :fast
                 | :noout
                 | :ignorecrop
                 | :local_header
                 | :chunks
                 | :showall
                 | :export_mvs
                 | :skip_manual
                 | :ass_ro_flush_noop
                 | :icc_profiles
               ]
             | :fast
             | :noout
             | :ignorecrop
             | :local_header
             | :chunks
             | :showall
             | :export_mvs
             | :skip_manual
             | :ass_ro_flush_noop
             | :icc_profiles}
          | {:lowres, integer() | String.t()}
          | {:strict,
             integer() | String.t() | :very | :strict | :normal | :unofficial | :experimental}
          | {:thread_type,
             integer() | String.t() | [String.t() | :slice | :frame] | :slice | :frame}
          | {:threads, integer() | String.t() | :auto}
          | {:raw, [Command.av_option()]}
  @doc """
  aac: AAC (Advanced Audio Coding)

  Configures the first audio stream; use the three-argument form for another index.

    * General capabilities: dr1 chconf
    * Threading capabilities: none
    * Supported sample formats: fltp
    * Supported channel layouts: mono stereo 3.0 4.0 5.0 5.1 7.1(wide) 6.1(back) 7.1 22.2 5.1.2

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `dual_mono_mode` (AAC decoder, :int): Select the channel to decode for dual mono (from -1 to 2) (default auto) Reported constants: auto, main, sub, both.
    * `channel_order` (AAC decoder, :int): Order in which the channels are to be exported (from 0 to 1) (default default) Reported constants: default, coded.
    * `flags` (AVCodecContext, :flags): (default 0) Reported constants: unaligned, mv4, qpel, loop, gray, psnr, ildct, low_delay, global_header, bitexact, aic, ilme, cgop, output_corrupt, drop_changed.
    * `flags2` (AVCodecContext, :flags): (default 0) Reported constants: fast, noout, ignorecrop, local_header, chunks, showall, export_mvs, skip_manual, ass_ro_flush_noop, icc_profiles.
    * `strict` (AVCodecContext, :int): how strictly to follow the standards (from INT_MIN to INT_MAX) (default normal) Reported constants: very, strict, normal, unofficial, experimental.
    * `err_detect` (AVCodecContext, :flags): set error detection flags (default 0) Reported constants: crccheck, bitstream, buffer, explode, ignore_err, careful, compliant, aggressive.
    * `threads` (AVCodecContext, :int): set the number of threads (from 0 to INT_MAX) (default 1) Reported constants: auto.
    * `lowres` (AVCodecContext, :int): decode at 1= 1/2, 2=1/4, 3=1/8 resolutions (from 0 to INT_MAX) (default 0)
    * `thread_type` (AVCodecContext, :flags): select multithreading type (default slice+frame) Reported constants: slice, frame.
  """
  @spec aac(Input.t(), [aac_option()]) :: Input.t()
  def aac(input, options \\ []), do: aac(input, {:audio, 0}, options)

  @doc "Configures an explicitly indexed input stream. See `aac/2` for options."
  @spec aac(Input.t(), Input.decoder_selector(), [aac_option()]) :: Input.t()
  def aac(input, selector, options) do
    check_media!(selector, :audio)
    options = Options.normalize!(options, @aac_schema, "aac decoder")
    named(input, selector, "aac", options)
  end

  @ac3_schema %{
    "cons_noisegen" => [%{type: :boolean, constants: []}],
    "downmix" => [%{type: :channel_layout, constants: []}],
    "drc_scale" => [%{type: :float, constants: []}],
    "err_detect" => [
      %{
        type: :flags,
        constants: [
          "crccheck",
          "bitstream",
          "buffer",
          "explode",
          "ignore_err",
          "careful",
          "compliant",
          "aggressive"
        ]
      }
    ],
    "flags" => [
      %{
        type: :flags,
        constants: [
          "unaligned",
          "mv4",
          "qpel",
          "loop",
          "gray",
          "psnr",
          "ildct",
          "low_delay",
          "global_header",
          "bitexact",
          "aic",
          "ilme",
          "cgop",
          "output_corrupt",
          "drop_changed"
        ]
      }
    ],
    "flags2" => [
      %{
        type: :flags,
        constants: [
          "fast",
          "noout",
          "ignorecrop",
          "local_header",
          "chunks",
          "showall",
          "export_mvs",
          "skip_manual",
          "ass_ro_flush_noop",
          "icc_profiles"
        ]
      }
    ],
    "heavy_compr" => [%{type: :boolean, constants: []}],
    "lowres" => [%{type: :int, constants: []}],
    "strict" => [
      %{type: :int, constants: ["very", "strict", "normal", "unofficial", "experimental"]}
    ],
    "target_level" => [%{type: :int, constants: []}],
    "thread_type" => [%{type: :flags, constants: ["slice", "frame"]}],
    "threads" => [%{type: :int, constants: ["auto"]}]
  }
  @type ac3_option ::
          {:cons_noisegen, boolean() | :auto | String.t()}
          | {:downmix, String.t() | atom()}
          | {:drc_scale, number() | String.t()}
          | {:err_detect,
             integer()
             | String.t()
             | [
                 String.t()
                 | :crccheck
                 | :bitstream
                 | :buffer
                 | :explode
                 | :ignore_err
                 | :careful
                 | :compliant
                 | :aggressive
               ]
             | :crccheck
             | :bitstream
             | :buffer
             | :explode
             | :ignore_err
             | :careful
             | :compliant
             | :aggressive}
          | {:flags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :unaligned
                 | :mv4
                 | :qpel
                 | :loop
                 | :gray
                 | :psnr
                 | :ildct
                 | :low_delay
                 | :global_header
                 | :bitexact
                 | :aic
                 | :ilme
                 | :cgop
                 | :output_corrupt
                 | :drop_changed
               ]
             | :unaligned
             | :mv4
             | :qpel
             | :loop
             | :gray
             | :psnr
             | :ildct
             | :low_delay
             | :global_header
             | :bitexact
             | :aic
             | :ilme
             | :cgop
             | :output_corrupt
             | :drop_changed}
          | {:flags2,
             integer()
             | String.t()
             | [
                 String.t()
                 | :fast
                 | :noout
                 | :ignorecrop
                 | :local_header
                 | :chunks
                 | :showall
                 | :export_mvs
                 | :skip_manual
                 | :ass_ro_flush_noop
                 | :icc_profiles
               ]
             | :fast
             | :noout
             | :ignorecrop
             | :local_header
             | :chunks
             | :showall
             | :export_mvs
             | :skip_manual
             | :ass_ro_flush_noop
             | :icc_profiles}
          | {:heavy_compr, boolean() | :auto | String.t()}
          | {:lowres, integer() | String.t()}
          | {:strict,
             integer() | String.t() | :very | :strict | :normal | :unofficial | :experimental}
          | {:target_level, integer() | String.t()}
          | {:thread_type,
             integer() | String.t() | [String.t() | :slice | :frame] | :slice | :frame}
          | {:threads, integer() | String.t() | :auto}
          | {:raw, [Command.av_option()]}
  @doc """
  ac3: ATSC A/52A (AC-3)

  Configures the first audio stream; use the three-argument form for another index.

    * General capabilities: dr1 chconf
    * Threading capabilities: none
    * Supported sample formats: fltp

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `cons_noisegen` ((E-)AC3 decoder, :boolean): enable consistent noise generation (default false)
    * `drc_scale` ((E-)AC3 decoder, :float): percentage of dynamic range compression to apply (from 0 to 6) (default 1)
    * `heavy_compr` ((E-)AC3 decoder, :boolean): enable heavy dynamic range compression (default false)
    * `target_level` ((E-)AC3 decoder, :int): target level in -dBFS (0 not applied) (from -31 to 0) (default 0)
    * `downmix` ((E-)AC3 decoder, :channel_layout): Request a specific channel layout from the decoder
    * `flags` (AVCodecContext, :flags): (default 0) Reported constants: unaligned, mv4, qpel, loop, gray, psnr, ildct, low_delay, global_header, bitexact, aic, ilme, cgop, output_corrupt, drop_changed.
    * `flags2` (AVCodecContext, :flags): (default 0) Reported constants: fast, noout, ignorecrop, local_header, chunks, showall, export_mvs, skip_manual, ass_ro_flush_noop, icc_profiles.
    * `strict` (AVCodecContext, :int): how strictly to follow the standards (from INT_MIN to INT_MAX) (default normal) Reported constants: very, strict, normal, unofficial, experimental.
    * `err_detect` (AVCodecContext, :flags): set error detection flags (default 0) Reported constants: crccheck, bitstream, buffer, explode, ignore_err, careful, compliant, aggressive.
    * `threads` (AVCodecContext, :int): set the number of threads (from 0 to INT_MAX) (default 1) Reported constants: auto.
    * `lowres` (AVCodecContext, :int): decode at 1= 1/2, 2=1/4, 3=1/8 resolutions (from 0 to INT_MAX) (default 0)
    * `thread_type` (AVCodecContext, :flags): select multithreading type (default slice+frame) Reported constants: slice, frame.
  """
  @spec ac3(Input.t(), [ac3_option()]) :: Input.t()
  def ac3(input, options \\ []), do: ac3(input, {:audio, 0}, options)

  @doc "Configures an explicitly indexed input stream. See `ac3/2` for options."
  @spec ac3(Input.t(), Input.decoder_selector(), [ac3_option()]) :: Input.t()
  def ac3(input, selector, options) do
    check_media!(selector, :audio)
    options = Options.normalize!(options, @ac3_schema, "ac3 decoder")
    named(input, selector, "ac3", options)
  end

  @mpeg4_schema %{
    "err_detect" => [
      %{
        type: :flags,
        constants: [
          "crccheck",
          "bitstream",
          "buffer",
          "explode",
          "ignore_err",
          "careful",
          "compliant",
          "aggressive"
        ]
      }
    ],
    "flags" => [
      %{
        type: :flags,
        constants: [
          "unaligned",
          "mv4",
          "qpel",
          "loop",
          "gray",
          "psnr",
          "ildct",
          "low_delay",
          "global_header",
          "bitexact",
          "aic",
          "ilme",
          "cgop",
          "output_corrupt",
          "drop_changed"
        ]
      }
    ],
    "flags2" => [
      %{
        type: :flags,
        constants: [
          "fast",
          "noout",
          "ignorecrop",
          "local_header",
          "chunks",
          "showall",
          "export_mvs",
          "skip_manual",
          "ass_ro_flush_noop",
          "icc_profiles"
        ]
      }
    ],
    "lowres" => [%{type: :int, constants: []}],
    "skip_frame" => [
      %{type: :int, constants: ["none", "default", "noref", "bidir", "nointra", "nokey", "all"]}
    ],
    "skip_idct" => [
      %{type: :int, constants: ["none", "default", "noref", "bidir", "nointra", "nokey", "all"]}
    ],
    "skip_loop_filter" => [
      %{type: :int, constants: ["none", "default", "noref", "bidir", "nointra", "nokey", "all"]}
    ],
    "strict" => [
      %{type: :int, constants: ["very", "strict", "normal", "unofficial", "experimental"]}
    ],
    "thread_type" => [%{type: :flags, constants: ["slice", "frame"]}],
    "threads" => [%{type: :int, constants: ["auto"]}]
  }
  @type mpeg4_option ::
          {:err_detect,
           integer()
           | String.t()
           | [
               String.t()
               | :crccheck
               | :bitstream
               | :buffer
               | :explode
               | :ignore_err
               | :careful
               | :compliant
               | :aggressive
             ]
           | :crccheck
           | :bitstream
           | :buffer
           | :explode
           | :ignore_err
           | :careful
           | :compliant
           | :aggressive}
          | {:flags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :unaligned
                 | :mv4
                 | :qpel
                 | :loop
                 | :gray
                 | :psnr
                 | :ildct
                 | :low_delay
                 | :global_header
                 | :bitexact
                 | :aic
                 | :ilme
                 | :cgop
                 | :output_corrupt
                 | :drop_changed
               ]
             | :unaligned
             | :mv4
             | :qpel
             | :loop
             | :gray
             | :psnr
             | :ildct
             | :low_delay
             | :global_header
             | :bitexact
             | :aic
             | :ilme
             | :cgop
             | :output_corrupt
             | :drop_changed}
          | {:flags2,
             integer()
             | String.t()
             | [
                 String.t()
                 | :fast
                 | :noout
                 | :ignorecrop
                 | :local_header
                 | :chunks
                 | :showall
                 | :export_mvs
                 | :skip_manual
                 | :ass_ro_flush_noop
                 | :icc_profiles
               ]
             | :fast
             | :noout
             | :ignorecrop
             | :local_header
             | :chunks
             | :showall
             | :export_mvs
             | :skip_manual
             | :ass_ro_flush_noop
             | :icc_profiles}
          | {:lowres, integer() | String.t()}
          | {:skip_frame,
             integer()
             | String.t()
             | :none
             | :default
             | :noref
             | :bidir
             | :nointra
             | :nokey
             | :all}
          | {:skip_idct,
             integer()
             | String.t()
             | :none
             | :default
             | :noref
             | :bidir
             | :nointra
             | :nokey
             | :all}
          | {:skip_loop_filter,
             integer()
             | String.t()
             | :none
             | :default
             | :noref
             | :bidir
             | :nointra
             | :nokey
             | :all}
          | {:strict,
             integer() | String.t() | :very | :strict | :normal | :unofficial | :experimental}
          | {:thread_type,
             integer() | String.t() | [String.t() | :slice | :frame] | :slice | :frame}
          | {:threads, integer() | String.t() | :auto}
          | {:raw, [Command.av_option()]}
  @doc """
  mpeg4: MPEG-4 part 2

  Configures the first video stream; use the three-argument form for another index.

    * General capabilities: horizband dr1 delay threads
    * Threading capabilities: frame
    * Supported hardware devices: cuda vaapi vdpau

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `flags` (AVCodecContext, :flags): (default 0) Reported constants: unaligned, mv4, qpel, loop, gray, psnr, ildct, low_delay, global_header, bitexact, aic, ilme, cgop, output_corrupt, drop_changed.
    * `flags2` (AVCodecContext, :flags): (default 0) Reported constants: fast, noout, ignorecrop, local_header, chunks, showall, export_mvs, skip_manual, ass_ro_flush_noop, icc_profiles.
    * `strict` (AVCodecContext, :int): how strictly to follow the standards (from INT_MIN to INT_MAX) (default normal) Reported constants: very, strict, normal, unofficial, experimental.
    * `err_detect` (AVCodecContext, :flags): set error detection flags (default 0) Reported constants: crccheck, bitstream, buffer, explode, ignore_err, careful, compliant, aggressive.
    * `threads` (AVCodecContext, :int): set the number of threads (from 0 to INT_MAX) (default 1) Reported constants: auto.
    * `lowres` (AVCodecContext, :int): decode at 1= 1/2, 2=1/4, 3=1/8 resolutions (from 0 to INT_MAX) (default 0)
    * `skip_loop_filter` (AVCodecContext, :int): skip loop filtering process for the selected frames (from INT_MIN to INT_MAX) (default default) Reported constants: none, default, noref, bidir, nointra, nokey, all.
    * `skip_idct` (AVCodecContext, :int): skip IDCT/dequantization for the selected frames (from INT_MIN to INT_MAX) (default default) Reported constants: none, default, noref, bidir, nointra, nokey, all.
    * `skip_frame` (AVCodecContext, :int): skip decoding for the selected frames (from INT_MIN to INT_MAX) (default default) Reported constants: none, default, noref, bidir, nointra, nokey, all.
    * `thread_type` (AVCodecContext, :flags): select multithreading type (default slice+frame) Reported constants: slice, frame.
  """
  @spec mpeg4(Input.t(), [mpeg4_option()]) :: Input.t()
  def mpeg4(input, options \\ []), do: mpeg4(input, {:video, 0}, options)

  @doc "Configures an explicitly indexed input stream. See `mpeg4/2` for options."
  @spec mpeg4(Input.t(), Input.decoder_selector(), [mpeg4_option()]) :: Input.t()
  def mpeg4(input, selector, options) do
    check_media!(selector, :video)
    options = Options.normalize!(options, @mpeg4_schema, "mpeg4 decoder")
    named(input, selector, "mpeg4", options)
  end

  @rawvideo_schema %{
    "err_detect" => [
      %{
        type: :flags,
        constants: [
          "crccheck",
          "bitstream",
          "buffer",
          "explode",
          "ignore_err",
          "careful",
          "compliant",
          "aggressive"
        ]
      }
    ],
    "flags" => [
      %{
        type: :flags,
        constants: [
          "unaligned",
          "mv4",
          "qpel",
          "loop",
          "gray",
          "psnr",
          "ildct",
          "low_delay",
          "global_header",
          "bitexact",
          "aic",
          "ilme",
          "cgop",
          "output_corrupt",
          "drop_changed"
        ]
      }
    ],
    "flags2" => [
      %{
        type: :flags,
        constants: [
          "fast",
          "noout",
          "ignorecrop",
          "local_header",
          "chunks",
          "showall",
          "export_mvs",
          "skip_manual",
          "ass_ro_flush_noop",
          "icc_profiles"
        ]
      }
    ],
    "lowres" => [%{type: :int, constants: []}],
    "skip_frame" => [
      %{type: :int, constants: ["none", "default", "noref", "bidir", "nointra", "nokey", "all"]}
    ],
    "skip_idct" => [
      %{type: :int, constants: ["none", "default", "noref", "bidir", "nointra", "nokey", "all"]}
    ],
    "skip_loop_filter" => [
      %{type: :int, constants: ["none", "default", "noref", "bidir", "nointra", "nokey", "all"]}
    ],
    "strict" => [
      %{type: :int, constants: ["very", "strict", "normal", "unofficial", "experimental"]}
    ],
    "thread_type" => [%{type: :flags, constants: ["slice", "frame"]}],
    "threads" => [%{type: :int, constants: ["auto"]}],
    "top" => [%{type: :boolean, constants: []}]
  }
  @type rawvideo_option ::
          {:err_detect,
           integer()
           | String.t()
           | [
               String.t()
               | :crccheck
               | :bitstream
               | :buffer
               | :explode
               | :ignore_err
               | :careful
               | :compliant
               | :aggressive
             ]
           | :crccheck
           | :bitstream
           | :buffer
           | :explode
           | :ignore_err
           | :careful
           | :compliant
           | :aggressive}
          | {:flags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :unaligned
                 | :mv4
                 | :qpel
                 | :loop
                 | :gray
                 | :psnr
                 | :ildct
                 | :low_delay
                 | :global_header
                 | :bitexact
                 | :aic
                 | :ilme
                 | :cgop
                 | :output_corrupt
                 | :drop_changed
               ]
             | :unaligned
             | :mv4
             | :qpel
             | :loop
             | :gray
             | :psnr
             | :ildct
             | :low_delay
             | :global_header
             | :bitexact
             | :aic
             | :ilme
             | :cgop
             | :output_corrupt
             | :drop_changed}
          | {:flags2,
             integer()
             | String.t()
             | [
                 String.t()
                 | :fast
                 | :noout
                 | :ignorecrop
                 | :local_header
                 | :chunks
                 | :showall
                 | :export_mvs
                 | :skip_manual
                 | :ass_ro_flush_noop
                 | :icc_profiles
               ]
             | :fast
             | :noout
             | :ignorecrop
             | :local_header
             | :chunks
             | :showall
             | :export_mvs
             | :skip_manual
             | :ass_ro_flush_noop
             | :icc_profiles}
          | {:lowres, integer() | String.t()}
          | {:skip_frame,
             integer()
             | String.t()
             | :none
             | :default
             | :noref
             | :bidir
             | :nointra
             | :nokey
             | :all}
          | {:skip_idct,
             integer()
             | String.t()
             | :none
             | :default
             | :noref
             | :bidir
             | :nointra
             | :nokey
             | :all}
          | {:skip_loop_filter,
             integer()
             | String.t()
             | :none
             | :default
             | :noref
             | :bidir
             | :nointra
             | :nokey
             | :all}
          | {:strict,
             integer() | String.t() | :very | :strict | :normal | :unofficial | :experimental}
          | {:thread_type,
             integer() | String.t() | [String.t() | :slice | :frame] | :slice | :frame}
          | {:threads, integer() | String.t() | :auto}
          | {:top, boolean() | :auto | String.t()}
          | {:raw, [Command.av_option()]}
  @doc """
  rawvideo: raw video

  Configures the first video stream; use the three-argument form for another index.

    * General capabilities: paramchange
    * Threading capabilities: none

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `top` (rawdec, :boolean): top field first (default auto)
    * `flags` (AVCodecContext, :flags): (default 0) Reported constants: unaligned, mv4, qpel, loop, gray, psnr, ildct, low_delay, global_header, bitexact, aic, ilme, cgop, output_corrupt, drop_changed.
    * `flags2` (AVCodecContext, :flags): (default 0) Reported constants: fast, noout, ignorecrop, local_header, chunks, showall, export_mvs, skip_manual, ass_ro_flush_noop, icc_profiles.
    * `strict` (AVCodecContext, :int): how strictly to follow the standards (from INT_MIN to INT_MAX) (default normal) Reported constants: very, strict, normal, unofficial, experimental.
    * `err_detect` (AVCodecContext, :flags): set error detection flags (default 0) Reported constants: crccheck, bitstream, buffer, explode, ignore_err, careful, compliant, aggressive.
    * `threads` (AVCodecContext, :int): set the number of threads (from 0 to INT_MAX) (default 1) Reported constants: auto.
    * `lowres` (AVCodecContext, :int): decode at 1= 1/2, 2=1/4, 3=1/8 resolutions (from 0 to INT_MAX) (default 0)
    * `skip_loop_filter` (AVCodecContext, :int): skip loop filtering process for the selected frames (from INT_MIN to INT_MAX) (default default) Reported constants: none, default, noref, bidir, nointra, nokey, all.
    * `skip_idct` (AVCodecContext, :int): skip IDCT/dequantization for the selected frames (from INT_MIN to INT_MAX) (default default) Reported constants: none, default, noref, bidir, nointra, nokey, all.
    * `skip_frame` (AVCodecContext, :int): skip decoding for the selected frames (from INT_MIN to INT_MAX) (default default) Reported constants: none, default, noref, bidir, nointra, nokey, all.
    * `thread_type` (AVCodecContext, :flags): select multithreading type (default slice+frame) Reported constants: slice, frame.
  """
  @spec rawvideo(Input.t(), [rawvideo_option()]) :: Input.t()
  def rawvideo(input, options \\ []), do: rawvideo(input, {:video, 0}, options)

  @doc "Configures an explicitly indexed input stream. See `rawvideo/2` for options."
  @spec rawvideo(Input.t(), Input.decoder_selector(), [rawvideo_option()]) :: Input.t()
  def rawvideo(input, selector, options) do
    check_media!(selector, :video)
    options = Options.normalize!(options, @rawvideo_schema, "rawvideo decoder")
    named(input, selector, "rawvideo", options)
  end

  @pcm_s16le_schema %{
    "err_detect" => [
      %{
        type: :flags,
        constants: [
          "crccheck",
          "bitstream",
          "buffer",
          "explode",
          "ignore_err",
          "careful",
          "compliant",
          "aggressive"
        ]
      }
    ],
    "flags" => [
      %{
        type: :flags,
        constants: [
          "unaligned",
          "mv4",
          "qpel",
          "loop",
          "gray",
          "psnr",
          "ildct",
          "low_delay",
          "global_header",
          "bitexact",
          "aic",
          "ilme",
          "cgop",
          "output_corrupt",
          "drop_changed"
        ]
      }
    ],
    "flags2" => [
      %{
        type: :flags,
        constants: [
          "fast",
          "noout",
          "ignorecrop",
          "local_header",
          "chunks",
          "showall",
          "export_mvs",
          "skip_manual",
          "ass_ro_flush_noop",
          "icc_profiles"
        ]
      }
    ],
    "lowres" => [%{type: :int, constants: []}],
    "strict" => [
      %{type: :int, constants: ["very", "strict", "normal", "unofficial", "experimental"]}
    ],
    "thread_type" => [%{type: :flags, constants: ["slice", "frame"]}],
    "threads" => [%{type: :int, constants: ["auto"]}]
  }
  @type pcm_s16le_option ::
          {:err_detect,
           integer()
           | String.t()
           | [
               String.t()
               | :crccheck
               | :bitstream
               | :buffer
               | :explode
               | :ignore_err
               | :careful
               | :compliant
               | :aggressive
             ]
           | :crccheck
           | :bitstream
           | :buffer
           | :explode
           | :ignore_err
           | :careful
           | :compliant
           | :aggressive}
          | {:flags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :unaligned
                 | :mv4
                 | :qpel
                 | :loop
                 | :gray
                 | :psnr
                 | :ildct
                 | :low_delay
                 | :global_header
                 | :bitexact
                 | :aic
                 | :ilme
                 | :cgop
                 | :output_corrupt
                 | :drop_changed
               ]
             | :unaligned
             | :mv4
             | :qpel
             | :loop
             | :gray
             | :psnr
             | :ildct
             | :low_delay
             | :global_header
             | :bitexact
             | :aic
             | :ilme
             | :cgop
             | :output_corrupt
             | :drop_changed}
          | {:flags2,
             integer()
             | String.t()
             | [
                 String.t()
                 | :fast
                 | :noout
                 | :ignorecrop
                 | :local_header
                 | :chunks
                 | :showall
                 | :export_mvs
                 | :skip_manual
                 | :ass_ro_flush_noop
                 | :icc_profiles
               ]
             | :fast
             | :noout
             | :ignorecrop
             | :local_header
             | :chunks
             | :showall
             | :export_mvs
             | :skip_manual
             | :ass_ro_flush_noop
             | :icc_profiles}
          | {:lowres, integer() | String.t()}
          | {:strict,
             integer() | String.t() | :very | :strict | :normal | :unofficial | :experimental}
          | {:thread_type,
             integer() | String.t() | [String.t() | :slice | :frame] | :slice | :frame}
          | {:threads, integer() | String.t() | :auto}
          | {:raw, [Command.av_option()]}
  @doc """
  pcm_s16le: PCM signed 16-bit little-endian

  Configures the first audio stream; use the three-argument form for another index.

    * General capabilities: dr1 paramchange
    * Threading capabilities: none
    * Supported sample formats: s16

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `flags` (AVCodecContext, :flags): (default 0) Reported constants: unaligned, mv4, qpel, loop, gray, psnr, ildct, low_delay, global_header, bitexact, aic, ilme, cgop, output_corrupt, drop_changed.
    * `flags2` (AVCodecContext, :flags): (default 0) Reported constants: fast, noout, ignorecrop, local_header, chunks, showall, export_mvs, skip_manual, ass_ro_flush_noop, icc_profiles.
    * `strict` (AVCodecContext, :int): how strictly to follow the standards (from INT_MIN to INT_MAX) (default normal) Reported constants: very, strict, normal, unofficial, experimental.
    * `err_detect` (AVCodecContext, :flags): set error detection flags (default 0) Reported constants: crccheck, bitstream, buffer, explode, ignore_err, careful, compliant, aggressive.
    * `threads` (AVCodecContext, :int): set the number of threads (from 0 to INT_MAX) (default 1) Reported constants: auto.
    * `lowres` (AVCodecContext, :int): decode at 1= 1/2, 2=1/4, 3=1/8 resolutions (from 0 to INT_MAX) (default 0)
    * `thread_type` (AVCodecContext, :flags): select multithreading type (default slice+frame) Reported constants: slice, frame.
  """
  @spec pcm_s16le(Input.t(), [pcm_s16le_option()]) :: Input.t()
  def pcm_s16le(input, options \\ []), do: pcm_s16le(input, {:audio, 0}, options)

  @doc "Configures an explicitly indexed input stream. See `pcm_s16le/2` for options."
  @spec pcm_s16le(Input.t(), Input.decoder_selector(), [pcm_s16le_option()]) :: Input.t()
  def pcm_s16le(input, selector, options) do
    check_media!(selector, :audio)
    options = Options.normalize!(options, @pcm_s16le_schema, "pcm_s16le decoder")
    named(input, selector, "pcm_s16le", options)
  end

  # END GENERATED HELPERS
end
