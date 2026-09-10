defmodule FFix.Encoder do
  @moduledoc """
  Source-taking encoder shortcuts and low-level encoder configuration.

  Named helpers return `FFix.Command.Mapping` values, not filterable streams or
  running encoder instances. Use them after filtering, inside an output callback
  or a one-callback `FFix.command/2` pipeline.

      FFix.Encoder.libx264(video, crf: 18, preset: "slow")

  Each mapping is an independent output use. Reusing a mapping in two output
  declarations does not share encoded packets. Stream copy is expressed with
  `FFix.stream_copy/1`, not an encoder named `"copy"`.

  Named helpers use a recorded metadata baseline, not the installed executable.
  They check option names and basic value shapes, but do not infer defaults or
  guarantee installation, hardware usability, or codec/container compatibility.
  Strings remain open FFmpeg values. Flag lists are normalized to FFmpeg strings.
  `raw: [{"new_option", "value"}]` bypasses metadata checks for individual options.

  `named/3` accepts dynamic registration names without a metadata schema. `new/2`
  constructs a standalone configuration for the lower-level command model.
  All component option names are unscoped and have no leading dash. Values may
  also be callbacks receiving the output's named stream information; see
  `FFix.Command.Output`. Their metadata checks run when the command is serialized.
  """

  alias FFix.Command
  alias FFix.Command.Mapping
  alias FFix.Options

  @type t :: %__MODULE__{name: String.t() | nil, options: [Command.output_av_option()]}
  defstruct [:name, options: []]

  @doc "Builds an unbound configuration without metadata lookup; nil leaves selection to FFmpeg."
  @spec new(String.t() | nil, [Command.output_av_option()]) :: t()
  def new(name, options \\ []) do
    Command.validate_component!(%__MODULE__{name: name, options: options})
  end

  @doc "Maps a source using a dynamic encoder name and unscoped options, without a metadata schema."
  @spec named(Command.source(), String.t(), list()) :: Mapping.t()
  def named(source, name, options \\ []) do
    options = Options.normalize!(options, nil, "#{name} encoder")
    Mapping.new(source, new(name, options))
  end

  # BEGIN GENERATED HELPERS
  @libx264_schema %{
    "x264opts" => [%{type: :string, constants: []}],
    "stats" => [%{type: :string, constants: []}],
    "weightp" => [%{type: :int, constants: ["none", "simple", "smart"]}],
    "crf_max" => [%{type: :float, constants: []}],
    "compression_level" => [%{type: :int, constants: []}],
    "psy-rd" => [%{type: :string, constants: []}],
    "intra-refresh" => [%{type: :boolean, constants: []}],
    "rc-lookahead" => [%{type: :int, constants: []}],
    "coder" => [%{type: :int, constants: ["default", "cavlc", "cabac", "vlc", "ac"]}],
    "slice-max-size" => [%{type: :int, constants: []}],
    "aq-strength" => [%{type: :float, constants: []}],
    "b-bias" => [%{type: :int, constants: []}],
    "level" => [%{type: :string, constants: []}, %{type: :int, constants: ["unknown"]}],
    "b" => [%{type: :int64, constants: []}],
    "threads" => [%{type: :int, constants: ["auto"]}],
    "cplxblur" => [%{type: :float, constants: []}],
    "tune" => [%{type: :string, constants: []}],
    "bufsize" => [%{type: :int, constants: []}],
    "global_quality" => [%{type: :int, constants: []}],
    "wpredp" => [%{type: :string, constants: []}],
    "strict" => [
      %{type: :int, constants: ["very", "strict", "normal", "unofficial", "experimental"]}
    ],
    "x264-params" => [%{type: :dictionary, constants: []}],
    "mbtree" => [%{type: :boolean, constants: []}],
    "nal-hrd" => [%{type: :int, constants: ["none", "vbr", "cbr"]}],
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
    "fast-pskip" => [%{type: :boolean, constants: []}],
    "fastfirstpass" => [%{type: :boolean, constants: []}],
    "weightb" => [%{type: :boolean, constants: []}],
    "avcintra-class" => [%{type: :int, constants: []}],
    "chromaoffset" => [%{type: :int, constants: []}],
    "sc_threshold" => [%{type: :int, constants: []}],
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
    "deblock" => [%{type: :string, constants: []}],
    "me_method" => [%{type: :int, constants: ["dia", "hex", "umh", "esa", "tesa"]}],
    "psy" => [%{type: :boolean, constants: []}],
    "crf" => [%{type: :float, constants: []}],
    "passlogfile" => [%{type: :string, constants: []}],
    "g" => [%{type: :int, constants: []}],
    "bluray-compat" => [%{type: :boolean, constants: []}],
    "ssim" => [%{type: :boolean, constants: []}],
    "forced-idr" => [%{type: :boolean, constants: []}],
    "profile" => [
      %{type: :string, constants: []},
      %{type: :int, constants: ["unknown", "main10"]}
    ],
    "aud" => [%{type: :boolean, constants: []}],
    "preset" => [%{type: :string, constants: []}],
    "noise_reduction" => [%{type: :int, constants: []}],
    "a53cc" => [%{type: :boolean, constants: []}],
    "motion-est" => [%{type: :int, constants: ["dia", "hex", "umh", "esa", "tesa"]}],
    "aq-mode" => [
      %{type: :int, constants: ["none", "variance", "autovariance", "autovariance-biased"]}
    ],
    "minrate" => [%{type: :int64, constants: []}],
    "b_strategy" => [%{type: :int, constants: []}],
    "maxrate" => [%{type: :int64, constants: []}],
    "direct-pred" => [%{type: :int, constants: ["none", "spatial", "temporal", "auto"]}],
    "thread_type" => [%{type: :flags, constants: ["slice", "frame"]}],
    "b-pyramid" => [%{type: :int, constants: ["none", "strict", "normal"]}],
    "mb_info" => [%{type: :boolean, constants: []}],
    "qp" => [%{type: :int, constants: []}],
    "udu_sei" => [%{type: :boolean, constants: []}],
    "partitions" => [%{type: :string, constants: []}],
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
    "mixed-refs" => [%{type: :boolean, constants: []}],
    "8x8dct" => [%{type: :boolean, constants: []}]
  }
  @type libx264_option ::
          {:"8x8dct", boolean() | :auto | String.t() | Command.option_callback()}
          | {:a53cc, boolean() | :auto | String.t() | Command.option_callback()}
          | {:"aq-mode",
             integer()
             | String.t()
             | :none
             | :variance
             | :autovariance
             | :"autovariance-biased"
             | Command.option_callback()}
          | {:"aq-strength", number() | String.t() | Command.option_callback()}
          | {:aud, boolean() | :auto | String.t() | Command.option_callback()}
          | {:"avcintra-class", integer() | String.t() | Command.option_callback()}
          | {:b, integer() | String.t() | Command.option_callback()}
          | {:"b-bias", integer() | String.t() | Command.option_callback()}
          | {:"b-pyramid",
             integer() | String.t() | :none | :strict | :normal | Command.option_callback()}
          | {:b_strategy, integer() | String.t() | Command.option_callback()}
          | {:"bluray-compat", boolean() | :auto | String.t() | Command.option_callback()}
          | {:bufsize, integer() | String.t() | Command.option_callback()}
          | {:chromaoffset, integer() | String.t() | Command.option_callback()}
          | {:coder,
             integer()
             | String.t()
             | :default
             | :cavlc
             | :cabac
             | :vlc
             | :ac
             | Command.option_callback()}
          | {:compression_level, integer() | String.t() | Command.option_callback()}
          | {:cplxblur, number() | String.t() | Command.option_callback()}
          | {:crf, number() | String.t() | Command.option_callback()}
          | {:crf_max, number() | String.t() | Command.option_callback()}
          | {:deblock, String.t() | atom() | Command.option_callback()}
          | {:"direct-pred",
             integer()
             | String.t()
             | :none
             | :spatial
             | :temporal
             | :auto
             | Command.option_callback()}
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
             | :aggressive
             | Command.option_callback()}
          | {:"fast-pskip", boolean() | :auto | String.t() | Command.option_callback()}
          | {:fastfirstpass, boolean() | :auto | String.t() | Command.option_callback()}
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
             | :drop_changed
             | Command.option_callback()}
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
             | :icc_profiles
             | Command.option_callback()}
          | {:"forced-idr", boolean() | :auto | String.t() | Command.option_callback()}
          | {:g, integer() | String.t() | Command.option_callback()}
          | {:global_quality, integer() | String.t() | Command.option_callback()}
          | {:"intra-refresh", boolean() | :auto | String.t() | Command.option_callback()}
          | {:level, String.t() | atom() | integer() | :unknown | Command.option_callback()}
          | {:maxrate, integer() | String.t() | Command.option_callback()}
          | {:mb_info, boolean() | :auto | String.t() | Command.option_callback()}
          | {:mbtree, boolean() | :auto | String.t() | Command.option_callback()}
          | {:me_method,
             integer()
             | String.t()
             | :dia
             | :hex
             | :umh
             | :esa
             | :tesa
             | Command.option_callback()}
          | {:minrate, integer() | String.t() | Command.option_callback()}
          | {:"mixed-refs", boolean() | :auto | String.t() | Command.option_callback()}
          | {:"motion-est",
             integer()
             | String.t()
             | :dia
             | :hex
             | :umh
             | :esa
             | :tesa
             | Command.option_callback()}
          | {:"nal-hrd", integer() | String.t() | :none | :vbr | :cbr | Command.option_callback()}
          | {:noise_reduction, integer() | String.t() | Command.option_callback()}
          | {:partitions, String.t() | atom() | Command.option_callback()}
          | {:passlogfile, String.t() | atom() | Command.option_callback()}
          | {:preset, String.t() | atom() | Command.option_callback()}
          | {:profile,
             String.t() | atom() | integer() | :unknown | :main10 | Command.option_callback()}
          | {:psy, boolean() | :auto | String.t() | Command.option_callback()}
          | {:"psy-rd", String.t() | atom() | Command.option_callback()}
          | {:qp, integer() | String.t() | Command.option_callback()}
          | {:"rc-lookahead", integer() | String.t() | Command.option_callback()}
          | {:sc_threshold, integer() | String.t() | Command.option_callback()}
          | {:"slice-max-size", integer() | String.t() | Command.option_callback()}
          | {:ssim, boolean() | :auto | String.t() | Command.option_callback()}
          | {:stats, String.t() | atom() | Command.option_callback()}
          | {:strict,
             integer()
             | String.t()
             | :very
             | :strict
             | :normal
             | :unofficial
             | :experimental
             | Command.option_callback()}
          | {:thread_type,
             integer()
             | String.t()
             | [String.t() | :slice | :frame]
             | :slice
             | :frame
             | Command.option_callback()}
          | {:threads, integer() | String.t() | :auto | Command.option_callback()}
          | {:tune, String.t() | atom() | Command.option_callback()}
          | {:udu_sei, boolean() | :auto | String.t() | Command.option_callback()}
          | {:weightb, boolean() | :auto | String.t() | Command.option_callback()}
          | {:weightp,
             integer() | String.t() | :none | :simple | :smart | Command.option_callback()}
          | {:wpredp, String.t() | atom() | Command.option_callback()}
          | {:"x264-params", String.t() | atom() | Command.option_callback()}
          | {:x264opts, String.t() | atom() | Command.option_callback()}
          | {:raw, [Command.output_av_option()]}
  @doc """
  libx264: libx264 H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10

  Maps one source to an independent encoded output stream.

    * General capabilities: dr1 delay threads
    * Threading capabilities: other
    * Supported pixel formats: yuv420p yuvj420p yuv422p yuvj422p yuv444p yuvj444p nv12 nv16 nv21 yuv420p10le yuv422p10le yuv444p10le nv20le gray gray10le

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `preset` (libx264, :string): Set the encoding preset (cf. x264 --fullhelp) (default \"medium\")
    * `tune` (libx264, :string): Tune the encoding params (cf. x264 --fullhelp)
    * `profile` (libx264, :string): Set profile restrictions (cf. x264 --fullhelp)
    * `fastfirstpass` (libx264, :boolean): Use fast settings when encoding first pass (default true)
    * `level` (libx264, :string): Specify level (as defined by Annex A)
    * `passlogfile` (libx264, :string): Filename for 2 pass stats
    * `wpredp` (libx264, :string): Weighted prediction for P-frames
    * `a53cc` (libx264, :boolean): Use A53 Closed Captions (if available) (default true)
    * `x264opts` (libx264, :string): x264 options
    * `crf` (libx264, :float): Select the quality for constant quality mode (from -1 to FLT_MAX) (default -1)
    * `crf_max` (libx264, :float): In CRF mode, prevents VBV from lowering quality beyond this point. (from -1 to FLT_MAX) (default -1)
    * `qp` (libx264, :int): Constant quantization parameter rate control method (from -1 to INT_MAX) (default -1)
    * `aq-mode` (libx264, :int): AQ method (from -1 to INT_MAX) (default -1) Reported constants: none, variance, autovariance, autovariance-biased.
    * `aq-strength` (libx264, :float): AQ strength. Reduces blocking and blurring in flat and textured areas. (from -1 to FLT_MAX) (default -1)
    * `psy` (libx264, :boolean): Use psychovisual optimizations. (default auto)
    * `psy-rd` (libx264, :string): Strength of psychovisual optimization, in <psy-rd>:<psy-trellis> format.
    * `rc-lookahead` (libx264, :int): Number of frames to look ahead for frametype and ratecontrol (from -1 to INT_MAX) (default -1)
    * `weightb` (libx264, :boolean): Weighted prediction for B-frames. (default auto)
    * `weightp` (libx264, :int): Weighted prediction analysis method. (from -1 to INT_MAX) (default -1) Reported constants: none, simple, smart.
    * `ssim` (libx264, :boolean): Calculate and print SSIM stats. (default auto)
    * `intra-refresh` (libx264, :boolean): Use Periodic Intra Refresh instead of IDR frames. (default auto)
    * `bluray-compat` (libx264, :boolean): Bluray compatibility workarounds. (default auto)
    * `b-bias` (libx264, :int): Influences how often B-frames are used (from INT_MIN to INT_MAX) (default INT_MIN)
    * `b-pyramid` (libx264, :int): Keep some B-frames as references. (from -1 to INT_MAX) (default -1) Reported constants: none, strict, normal.
    * `mixed-refs` (libx264, :boolean): One reference per partition, as opposed to one reference per macroblock (default auto)
    * `8x8dct` (libx264, :boolean): High profile 8x8 transform. (default auto)
    * `fast-pskip` (libx264, :boolean): (default auto)
    * `aud` (libx264, :boolean): Use access unit delimiters. (default auto)
    * `mbtree` (libx264, :boolean): Use macroblock tree ratecontrol. (default auto)
    * `deblock` (libx264, :string): Loop filter parameters, in <alpha:beta> form.
    * `cplxblur` (libx264, :float): Reduce fluctuations in QP (before curve compression) (from -1 to FLT_MAX) (default -1)
    * `partitions` (libx264, :string): A comma-separated list of partitions to consider. Possible values: p8x8, p4x4, b8x8, i8x8, i4x4, none, all
    * `direct-pred` (libx264, :int): Direct MV prediction mode (from -1 to INT_MAX) (default -1) Reported constants: none, spatial, temporal, auto.
    * `slice-max-size` (libx264, :int): Limit the size of each slice in bytes (from -1 to INT_MAX) (default -1)
    * `stats` (libx264, :string): Filename for 2 pass stats
    * `nal-hrd` (libx264, :int): Signal HRD information (requires vbv-bufsize; cbr not allowed in .mp4) (from -1 to INT_MAX) (default -1) Reported constants: none, vbr, cbr.
    * `avcintra-class` (libx264, :int): AVC-Intra class 50/100/200/300/480 (from -1 to 480) (default -1)
    * `me_method` (libx264, :int): Set motion estimation method (from -1 to 4) (default -1) Reported constants: dia, hex, umh, esa, tesa.
    * `motion-est` (libx264, :int): Set motion estimation method (from -1 to 4) (default -1) Reported constants: dia, hex, umh, esa, tesa.
    * `forced-idr` (libx264, :boolean): If forcing keyframes, force them as IDR frames. (default false)
    * `coder` (libx264, :int): Coder type (from -1 to 1) (default default) Reported constants: default, cavlc, cabac, vlc, ac.
    * `b_strategy` (libx264, :int): Strategy to choose between I/P/B-frames (from -1 to 2) (default -1)
    * `chromaoffset` (libx264, :int): QP difference between chroma and luma (from INT_MIN to INT_MAX) (default 0)
    * `sc_threshold` (libx264, :int): Scene change threshold (from INT_MIN to INT_MAX) (default -1)
    * `noise_reduction` (libx264, :int): Noise reduction (from INT_MIN to INT_MAX) (default -1)
    * `udu_sei` (libx264, :boolean): Use user data unregistered SEI if available (default false)
    * `x264-params` (libx264, :dictionary): Override the x264 configuration using a :-separated list of key=value parameters
    * `mb_info` (libx264, :boolean): Set mb_info data through AVSideData, only useful when used from the API (default false)
    * `b` (AVCodecContext, :int64): set bitrate (in bits/s) (from 0 to I64_MAX) (default 200000)
    * `flags` (AVCodecContext, :flags): (default 0) Reported constants: unaligned, mv4, qpel, loop, gray, psnr, ildct, low_delay, global_header, bitexact, aic, ilme, cgop, output_corrupt, drop_changed.
    * `flags2` (AVCodecContext, :flags): (default 0) Reported constants: fast, noout, ignorecrop, local_header, chunks, showall, export_mvs, skip_manual, ass_ro_flush_noop, icc_profiles.
    * `g` (AVCodecContext, :int): set the group of picture (GOP) size (from INT_MIN to INT_MAX) (default 12)
    * `strict` (AVCodecContext, :int): how strictly to follow the standards (from INT_MIN to INT_MAX) (default normal) Reported constants: very, strict, normal, unofficial, experimental.
    * `err_detect` (AVCodecContext, :flags): set error detection flags (default 0) Reported constants: crccheck, bitstream, buffer, explode, ignore_err, careful, compliant, aggressive.
    * `maxrate` (AVCodecContext, :int64): maximum bitrate (in bits/s). Used for VBV together with bufsize. (from 0 to INT_MAX) (default 0)
    * `minrate` (AVCodecContext, :int64): minimum bitrate (in bits/s). Most useful in setting up a CBR encode. It is of little use otherwise. (from INT_MIN to INT_MAX) (default 0)
    * `bufsize` (AVCodecContext, :int): set ratecontrol buffer size (in bits) (from INT_MIN to INT_MAX) (default 0)
    * `global_quality` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default 0)
    * `threads` (AVCodecContext, :int): set the number of threads (from 0 to INT_MAX) (default 1) Reported constants: auto.
    * `profile` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default unknown) Reported constants: unknown, main10.
    * `level` (AVCodecContext, :int): encoding level, usually corresponding to the profile level, codec-specific (from INT_MIN to INT_MAX) (default unknown) Reported constants: unknown.
    * `compression_level` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default -1)
    * `thread_type` (AVCodecContext, :flags): select multithreading type (default slice+frame) Reported constants: slice, frame.
  """
  @spec libx264(Command.source(), [libx264_option()]) :: Mapping.t()
  def libx264(source, options \\ []) do
    options = Options.normalize!(options, @libx264_schema, "libx264 encoder")
    named(source, "libx264", options)
  end

  @libx265_schema %{
    "a53cc" => [%{type: :boolean, constants: []}],
    "b" => [%{type: :int64, constants: []}],
    "bufsize" => [%{type: :int, constants: []}],
    "compression_level" => [%{type: :int, constants: []}],
    "crf" => [%{type: :float, constants: []}],
    "dolbyvision" => [%{type: :boolean, constants: ["auto"]}],
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
    "forced-idr" => [%{type: :boolean, constants: []}],
    "g" => [%{type: :int, constants: []}],
    "global_quality" => [%{type: :int, constants: []}],
    "level" => [%{type: :int, constants: ["unknown"]}],
    "maxrate" => [%{type: :int64, constants: []}],
    "minrate" => [%{type: :int64, constants: []}],
    "preset" => [%{type: :string, constants: []}],
    "profile" => [
      %{type: :string, constants: []},
      %{type: :int, constants: ["unknown", "main10"]}
    ],
    "qp" => [%{type: :int, constants: []}],
    "strict" => [
      %{type: :int, constants: ["very", "strict", "normal", "unofficial", "experimental"]}
    ],
    "thread_type" => [%{type: :flags, constants: ["slice", "frame"]}],
    "threads" => [%{type: :int, constants: ["auto"]}],
    "tune" => [%{type: :string, constants: []}],
    "udu_sei" => [%{type: :boolean, constants: []}],
    "x265-params" => [%{type: :dictionary, constants: []}]
  }
  @type libx265_option ::
          {:a53cc, boolean() | :auto | String.t() | Command.option_callback()}
          | {:b, integer() | String.t() | Command.option_callback()}
          | {:bufsize, integer() | String.t() | Command.option_callback()}
          | {:compression_level, integer() | String.t() | Command.option_callback()}
          | {:crf, number() | String.t() | Command.option_callback()}
          | {:dolbyvision, boolean() | :auto | String.t() | :auto | Command.option_callback()}
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
             | :aggressive
             | Command.option_callback()}
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
             | :drop_changed
             | Command.option_callback()}
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
             | :icc_profiles
             | Command.option_callback()}
          | {:"forced-idr", boolean() | :auto | String.t() | Command.option_callback()}
          | {:g, integer() | String.t() | Command.option_callback()}
          | {:global_quality, integer() | String.t() | Command.option_callback()}
          | {:level, integer() | String.t() | :unknown | Command.option_callback()}
          | {:maxrate, integer() | String.t() | Command.option_callback()}
          | {:minrate, integer() | String.t() | Command.option_callback()}
          | {:preset, String.t() | atom() | Command.option_callback()}
          | {:profile,
             String.t() | atom() | integer() | :unknown | :main10 | Command.option_callback()}
          | {:qp, integer() | String.t() | Command.option_callback()}
          | {:strict,
             integer()
             | String.t()
             | :very
             | :strict
             | :normal
             | :unofficial
             | :experimental
             | Command.option_callback()}
          | {:thread_type,
             integer()
             | String.t()
             | [String.t() | :slice | :frame]
             | :slice
             | :frame
             | Command.option_callback()}
          | {:threads, integer() | String.t() | :auto | Command.option_callback()}
          | {:tune, String.t() | atom() | Command.option_callback()}
          | {:udu_sei, boolean() | :auto | String.t() | Command.option_callback()}
          | {:"x265-params", String.t() | atom() | Command.option_callback()}
          | {:raw, [Command.output_av_option()]}
  @doc """
  libx265: libx265 H.265 / HEVC

  Maps one source to an independent encoded output stream.

    * General capabilities: dr1 delay threads
    * Threading capabilities: other
    * Supported pixel formats: yuv420p yuvj420p yuv422p yuvj422p yuv444p yuvj444p gbrp yuv420p10le yuv422p10le yuv444p10le gbrp10le yuv420p12le yuv422p12le yuv444p12le gbrp12le gray gray10le gray12le

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `crf` (libx265, :float): set the x265 crf (from -1 to FLT_MAX) (default -1)
    * `qp` (libx265, :int): set the x265 qp (from -1 to INT_MAX) (default -1)
    * `forced-idr` (libx265, :boolean): if forcing keyframes, force them as IDR frames (default false)
    * `preset` (libx265, :string): set the x265 preset
    * `tune` (libx265, :string): set the x265 tune parameter
    * `profile` (libx265, :string): set the x265 profile
    * `udu_sei` (libx265, :boolean): Use user data unregistered SEI if available (default false)
    * `a53cc` (libx265, :boolean): Use A53 Closed Captions (if available) (default false)
    * `x265-params` (libx265, :dictionary): set the x265 configuration using a :-separated list of key=value parameters
    * `dolbyvision` (libx265, :boolean): Enable Dolby Vision RPU coding (default auto) Reported constants: auto.
    * `b` (AVCodecContext, :int64): set bitrate (in bits/s) (from 0 to I64_MAX) (default 200000)
    * `flags` (AVCodecContext, :flags): (default 0) Reported constants: unaligned, mv4, qpel, loop, gray, psnr, ildct, low_delay, global_header, bitexact, aic, ilme, cgop, output_corrupt, drop_changed.
    * `flags2` (AVCodecContext, :flags): (default 0) Reported constants: fast, noout, ignorecrop, local_header, chunks, showall, export_mvs, skip_manual, ass_ro_flush_noop, icc_profiles.
    * `g` (AVCodecContext, :int): set the group of picture (GOP) size (from INT_MIN to INT_MAX) (default 12)
    * `strict` (AVCodecContext, :int): how strictly to follow the standards (from INT_MIN to INT_MAX) (default normal) Reported constants: very, strict, normal, unofficial, experimental.
    * `err_detect` (AVCodecContext, :flags): set error detection flags (default 0) Reported constants: crccheck, bitstream, buffer, explode, ignore_err, careful, compliant, aggressive.
    * `maxrate` (AVCodecContext, :int64): maximum bitrate (in bits/s). Used for VBV together with bufsize. (from 0 to INT_MAX) (default 0)
    * `minrate` (AVCodecContext, :int64): minimum bitrate (in bits/s). Most useful in setting up a CBR encode. It is of little use otherwise. (from INT_MIN to INT_MAX) (default 0)
    * `bufsize` (AVCodecContext, :int): set ratecontrol buffer size (in bits) (from INT_MIN to INT_MAX) (default 0)
    * `global_quality` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default 0)
    * `threads` (AVCodecContext, :int): set the number of threads (from 0 to INT_MAX) (default 1) Reported constants: auto.
    * `profile` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default unknown) Reported constants: unknown, main10.
    * `level` (AVCodecContext, :int): encoding level, usually corresponding to the profile level, codec-specific (from INT_MIN to INT_MAX) (default unknown) Reported constants: unknown.
    * `compression_level` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default -1)
    * `thread_type` (AVCodecContext, :flags): select multithreading type (default slice+frame) Reported constants: slice, frame.
  """
  @spec libx265(Command.source(), [libx265_option()]) :: Mapping.t()
  def libx265(source, options \\ []) do
    options = Options.normalize!(options, @libx265_schema, "libx265 encoder")
    named(source, "libx265", options)
  end

  @h264_nvenc_schema %{
    "compression_level" => [%{type: :int, constants: []}],
    "b_adapt" => [%{type: :boolean, constants: []}],
    "intra-refresh" => [%{type: :boolean, constants: []}],
    "init_qpP" => [%{type: :int, constants: []}],
    "no-scenecut" => [%{type: :boolean, constants: []}],
    "rc-lookahead" => [%{type: :int, constants: []}],
    "rc" => [
      %{
        type: :int,
        constants: [
          "constqp",
          "vbr",
          "cbr",
          "vbr_minqp",
          "ll_2pass_quality",
          "ll_2pass_size",
          "vbr_2pass",
          "cbr_ld_hq",
          "cbr_hq",
          "vbr_hq"
        ]
      }
    ],
    "coder" => [%{type: :int, constants: ["default", "auto", "cabac", "cavlc", "ac", "vlc"]}],
    "aq-strength" => [%{type: :int, constants: []}],
    "level" => [
      %{
        type: :int,
        constants: [
          "auto",
          "1",
          "1.0",
          "1b",
          "1.0b",
          "1.1",
          "1.2",
          "1.3",
          "2",
          "2.0",
          "2.1",
          "2.2",
          "3",
          "3.0",
          "3.1",
          "3.2",
          "4",
          "4.0",
          "4.1",
          "4.2",
          "5",
          "5.0",
          "5.1",
          "5.2",
          "6.0",
          "6.1",
          "6.2"
        ]
      },
      %{type: :int, constants: ["unknown"]}
    ],
    "b" => [%{type: :int64, constants: []}],
    "threads" => [%{type: :int, constants: ["auto"]}],
    "zerolatency" => [%{type: :boolean, constants: []}],
    "tune" => [%{type: :int, constants: ["hq", "ll", "ull", "lossless"]}],
    "weighted_pred" => [%{type: :int, constants: []}],
    "bufsize" => [%{type: :int, constants: []}],
    "global_quality" => [%{type: :int, constants: []}],
    "qp_cb_offset" => [%{type: :int, constants: []}],
    "strict" => [
      %{type: :int, constants: ["very", "strict", "normal", "unofficial", "experimental"]}
    ],
    "b_ref_mode" => [%{type: :int, constants: ["disabled", "each", "middle"]}],
    "spatial-aq" => [%{type: :boolean, constants: []}],
    "single-slice-intra-refresh" => [%{type: :boolean, constants: []}],
    "ldkfs" => [%{type: :int, constants: []}],
    "init_qpB" => [%{type: :int, constants: []}],
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
    "init_qpI" => [%{type: :int, constants: []}],
    "spatial_aq" => [%{type: :boolean, constants: []}],
    "nonref_p" => [%{type: :boolean, constants: []}],
    "2pass" => [%{type: :boolean, constants: []}],
    "constrained-encoding" => [%{type: :boolean, constants: []}],
    "lookahead_level" => [%{type: :int, constants: ["auto", "0", "1", "2", "3"]}],
    "surfaces" => [%{type: :int, constants: []}],
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
    "temporal-aq" => [%{type: :boolean, constants: []}],
    "cbr" => [%{type: :boolean, constants: []}],
    "extra_sei" => [%{type: :boolean, constants: []}],
    "temporal_aq" => [%{type: :boolean, constants: []}],
    "strict_gop" => [%{type: :boolean, constants: []}],
    "g" => [%{type: :int, constants: []}],
    "bluray-compat" => [%{type: :boolean, constants: []}],
    "delay" => [%{type: :int, constants: []}],
    "forced-idr" => [%{type: :boolean, constants: []}],
    "profile" => [
      %{type: :int, constants: ["baseline", "main", "high", "high444p"]},
      %{type: :int, constants: ["unknown", "main10"]}
    ],
    "aud" => [%{type: :boolean, constants: []}],
    "preset" => [
      %{
        type: :int,
        constants: [
          "default",
          "slow",
          "medium",
          "fast",
          "hp",
          "hq",
          "bd",
          "ll",
          "llhq",
          "llhp",
          "lossless",
          "losslesshp",
          "p1",
          "p2",
          "p3",
          "p4",
          "p5",
          "p6",
          "p7"
        ]
      }
    ],
    "a53cc" => [%{type: :boolean, constants: []}],
    "rgb_mode" => [%{type: :int, constants: ["yuv420", "yuv444", "disabled"]}],
    "gpu" => [%{type: :int, constants: ["any", "list"]}],
    "minrate" => [%{type: :int64, constants: []}],
    "maxrate" => [%{type: :int64, constants: []}],
    "dpb_size" => [%{type: :int, constants: []}],
    "qp_cr_offset" => [%{type: :int, constants: []}],
    "thread_type" => [%{type: :flags, constants: ["slice", "frame"]}],
    "multipass" => [%{type: :int, constants: ["disabled", "qres", "fullres"]}],
    "max_slice_size" => [%{type: :int, constants: []}],
    "qp" => [%{type: :int, constants: []}],
    "udu_sei" => [%{type: :boolean, constants: []}],
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
    "cq" => [%{type: :float, constants: []}]
  }
  @type h264_nvenc_option ::
          {:"2pass", boolean() | :auto | String.t() | Command.option_callback()}
          | {:a53cc, boolean() | :auto | String.t() | Command.option_callback()}
          | {:"aq-strength", integer() | String.t() | Command.option_callback()}
          | {:aud, boolean() | :auto | String.t() | Command.option_callback()}
          | {:b, integer() | String.t() | Command.option_callback()}
          | {:b_adapt, boolean() | :auto | String.t() | Command.option_callback()}
          | {:b_ref_mode,
             integer() | String.t() | :disabled | :each | :middle | Command.option_callback()}
          | {:"bluray-compat", boolean() | :auto | String.t() | Command.option_callback()}
          | {:bufsize, integer() | String.t() | Command.option_callback()}
          | {:cbr, boolean() | :auto | String.t() | Command.option_callback()}
          | {:coder,
             integer()
             | String.t()
             | :default
             | :auto
             | :cabac
             | :cavlc
             | :ac
             | :vlc
             | Command.option_callback()}
          | {:compression_level, integer() | String.t() | Command.option_callback()}
          | {:"constrained-encoding", boolean() | :auto | String.t() | Command.option_callback()}
          | {:cq, number() | String.t() | Command.option_callback()}
          | {:delay, integer() | String.t() | Command.option_callback()}
          | {:dpb_size, integer() | String.t() | Command.option_callback()}
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
             | :aggressive
             | Command.option_callback()}
          | {:extra_sei, boolean() | :auto | String.t() | Command.option_callback()}
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
             | :drop_changed
             | Command.option_callback()}
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
             | :icc_profiles
             | Command.option_callback()}
          | {:"forced-idr", boolean() | :auto | String.t() | Command.option_callback()}
          | {:g, integer() | String.t() | Command.option_callback()}
          | {:global_quality, integer() | String.t() | Command.option_callback()}
          | {:gpu, integer() | String.t() | :any | :list | Command.option_callback()}
          | {:init_qpB, integer() | String.t() | Command.option_callback()}
          | {:init_qpI, integer() | String.t() | Command.option_callback()}
          | {:init_qpP, integer() | String.t() | Command.option_callback()}
          | {:"intra-refresh", boolean() | :auto | String.t() | Command.option_callback()}
          | {:ldkfs, integer() | String.t() | Command.option_callback()}
          | {:level,
             integer()
             | String.t()
             | :auto
             | :"1"
             | :"1.0"
             | :"1b"
             | :"1.0b"
             | :"1.1"
             | :"1.2"
             | :"1.3"
             | :"2"
             | :"2.0"
             | :"2.1"
             | :"2.2"
             | :"3"
             | :"3.0"
             | :"3.1"
             | :"3.2"
             | :"4"
             | :"4.0"
             | :"4.1"
             | :"4.2"
             | :"5"
             | :"5.0"
             | :"5.1"
             | :"5.2"
             | :"6.0"
             | :"6.1"
             | :"6.2"
             | :unknown
             | Command.option_callback()}
          | {:lookahead_level,
             integer()
             | String.t()
             | :auto
             | :"0"
             | :"1"
             | :"2"
             | :"3"
             | Command.option_callback()}
          | {:max_slice_size, integer() | String.t() | Command.option_callback()}
          | {:maxrate, integer() | String.t() | Command.option_callback()}
          | {:minrate, integer() | String.t() | Command.option_callback()}
          | {:multipass,
             integer() | String.t() | :disabled | :qres | :fullres | Command.option_callback()}
          | {:"no-scenecut", boolean() | :auto | String.t() | Command.option_callback()}
          | {:nonref_p, boolean() | :auto | String.t() | Command.option_callback()}
          | {:preset,
             integer()
             | String.t()
             | :default
             | :slow
             | :medium
             | :fast
             | :hp
             | :hq
             | :bd
             | :ll
             | :llhq
             | :llhp
             | :lossless
             | :losslesshp
             | :p1
             | :p2
             | :p3
             | :p4
             | :p5
             | :p6
             | :p7
             | Command.option_callback()}
          | {:profile,
             integer()
             | String.t()
             | :baseline
             | :main
             | :high
             | :high444p
             | :unknown
             | :main10
             | Command.option_callback()}
          | {:qp, integer() | String.t() | Command.option_callback()}
          | {:qp_cb_offset, integer() | String.t() | Command.option_callback()}
          | {:qp_cr_offset, integer() | String.t() | Command.option_callback()}
          | {:rc,
             integer()
             | String.t()
             | :constqp
             | :vbr
             | :cbr
             | :vbr_minqp
             | :ll_2pass_quality
             | :ll_2pass_size
             | :vbr_2pass
             | :cbr_ld_hq
             | :cbr_hq
             | :vbr_hq
             | Command.option_callback()}
          | {:"rc-lookahead", integer() | String.t() | Command.option_callback()}
          | {:rgb_mode,
             integer() | String.t() | :yuv420 | :yuv444 | :disabled | Command.option_callback()}
          | {:"single-slice-intra-refresh",
             boolean() | :auto | String.t() | Command.option_callback()}
          | {:"spatial-aq", boolean() | :auto | String.t() | Command.option_callback()}
          | {:spatial_aq, boolean() | :auto | String.t() | Command.option_callback()}
          | {:strict,
             integer()
             | String.t()
             | :very
             | :strict
             | :normal
             | :unofficial
             | :experimental
             | Command.option_callback()}
          | {:strict_gop, boolean() | :auto | String.t() | Command.option_callback()}
          | {:surfaces, integer() | String.t() | Command.option_callback()}
          | {:"temporal-aq", boolean() | :auto | String.t() | Command.option_callback()}
          | {:temporal_aq, boolean() | :auto | String.t() | Command.option_callback()}
          | {:thread_type,
             integer()
             | String.t()
             | [String.t() | :slice | :frame]
             | :slice
             | :frame
             | Command.option_callback()}
          | {:threads, integer() | String.t() | :auto | Command.option_callback()}
          | {:tune,
             integer() | String.t() | :hq | :ll | :ull | :lossless | Command.option_callback()}
          | {:udu_sei, boolean() | :auto | String.t() | Command.option_callback()}
          | {:weighted_pred, integer() | String.t() | Command.option_callback()}
          | {:zerolatency, boolean() | :auto | String.t() | Command.option_callback()}
          | {:raw, [Command.output_av_option()]}
  @doc """
  h264_nvenc: NVIDIA NVENC H.264 encoder

  Maps one source to an independent encoded output stream.

    * General capabilities: dr1 delay hardware
    * Threading capabilities: none
    * Supported hardware devices: cuda cuda
    * Supported pixel formats: yuv420p nv12 p010le yuv444p p016le yuv444p16le bgr0 bgra rgb0 rgba x2rgb10le x2bgr10le gbrp gbrp16le cuda

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `preset` (h264_nvenc, :int): Set the encoding preset (from 0 to 18) (default p4) Reported constants: default, slow, medium, fast, hp, hq, bd, ll, llhq, llhp, lossless, losslesshp, p1, p2, p3, p4, p5, p6, p7.
    * `tune` (h264_nvenc, :int): Set the encoding tuning info (from 1 to 4) (default hq) Reported constants: hq, ll, ull, lossless.
    * `profile` (h264_nvenc, :int): Set the encoding profile (from 0 to 3) (default main) Reported constants: baseline, main, high, high444p.
    * `level` (h264_nvenc, :int): Set the encoding level restriction (from 0 to 62) (default auto) Reported constants: auto, 1, 1.0, 1b, 1.0b, 1.1, 1.2, 1.3, 2, 2.0, 2.1, 2.2, 3, 3.0, 3.1, 3.2, 4, 4.0, 4.1, 4.2, 5, 5.0, 5.1, 5.2, 6.0, 6.1, 6.2.
    * `rc` (h264_nvenc, :int): Override the preset rate-control (from -1 to INT_MAX) (default -1) Reported constants: constqp, vbr, cbr, vbr_minqp, ll_2pass_quality, ll_2pass_size, vbr_2pass, cbr_ld_hq, cbr_hq, vbr_hq.
    * `rc-lookahead` (h264_nvenc, :int): Number of frames to look ahead for rate-control (from 0 to INT_MAX) (default 0)
    * `surfaces` (h264_nvenc, :int): Number of concurrent surfaces (from 0 to 64) (default 0)
    * `cbr` (h264_nvenc, :boolean): Use cbr encoding mode (default false)
    * `2pass` (h264_nvenc, :boolean): Use 2pass encoding mode (default auto)
    * `gpu` (h264_nvenc, :int): Selects which NVENC capable GPU to use. First GPU is 0, second is 1, and so on. (from -2 to INT_MAX) (default any) Reported constants: any, list.
    * `rgb_mode` (h264_nvenc, :int): Configure how nvenc handles packed RGB input. (from 0 to INT_MAX) (default yuv420) Reported constants: yuv420, yuv444, disabled.
    * `delay` (h264_nvenc, :int): Delay frame output by the given amount of frames (from 0 to INT_MAX) (default INT_MAX)
    * `no-scenecut` (h264_nvenc, :boolean): When lookahead is enabled, set this to 1 to disable adaptive I-frame insertion at scene cuts (default false)
    * `forced-idr` (h264_nvenc, :boolean): If forcing keyframes, force them as IDR frames. (default false)
    * `b_adapt` (h264_nvenc, :boolean): When lookahead is enabled, set this to 0 to disable adaptive B-frame decision (default true)
    * `spatial-aq` (h264_nvenc, :boolean): set to 1 to enable Spatial AQ (default false)
    * `spatial_aq` (h264_nvenc, :boolean): set to 1 to enable Spatial AQ (default false)
    * `temporal-aq` (h264_nvenc, :boolean): set to 1 to enable Temporal AQ (default false)
    * `temporal_aq` (h264_nvenc, :boolean): set to 1 to enable Temporal AQ (default false)
    * `zerolatency` (h264_nvenc, :boolean): Set 1 to indicate zero latency operation (no reordering delay) (default false)
    * `nonref_p` (h264_nvenc, :boolean): Set this to 1 to enable automatic insertion of non-reference P-frames (default false)
    * `strict_gop` (h264_nvenc, :boolean): Set 1 to minimize GOP-to-GOP rate fluctuations (default false)
    * `aq-strength` (h264_nvenc, :int): When Spatial AQ is enabled, this field is used to specify AQ strength. AQ strength scale is from 1 (low) - 15 (aggressive) (from 1 to 15) (default 8)
    * `cq` (h264_nvenc, :float): Set target quality level (0 to 51, 0 means automatic) for constant quality mode in VBR rate control (from 0 to 51) (default 0)
    * `aud` (h264_nvenc, :boolean): Use access unit delimiters (default false)
    * `bluray-compat` (h264_nvenc, :boolean): Bluray compatibility workarounds (default false)
    * `init_qpP` (h264_nvenc, :int): Initial QP value for P frame (from -1 to 51) (default -1)
    * `init_qpB` (h264_nvenc, :int): Initial QP value for B frame (from -1 to 51) (default -1)
    * `init_qpI` (h264_nvenc, :int): Initial QP value for I frame (from -1 to 51) (default -1)
    * `qp` (h264_nvenc, :int): Constant quantization parameter rate control method (from -1 to 51) (default -1)
    * `qp_cb_offset` (h264_nvenc, :int): Quantization parameter offset for cb channel (from -12 to 12) (default 0)
    * `qp_cr_offset` (h264_nvenc, :int): Quantization parameter offset for cr channel (from -12 to 12) (default 0)
    * `weighted_pred` (h264_nvenc, :int): Set 1 to enable weighted prediction (from 0 to 1) (default 0)
    * `coder` (h264_nvenc, :int): Coder type (from -1 to 2) (default default) Reported constants: default, auto, cabac, cavlc, ac, vlc.
    * `b_ref_mode` (h264_nvenc, :int): Use B frames as references (from -1 to 2) (default -1) Reported constants: disabled, each, middle.
    * `a53cc` (h264_nvenc, :boolean): Use A53 Closed Captions (if available) (default true)
    * `dpb_size` (h264_nvenc, :int): Specifies the DPB size used for encoding (0 means automatic) (from 0 to INT_MAX) (default 0)
    * `multipass` (h264_nvenc, :int): Set the multipass encoding (from 0 to 2) (default disabled) Reported constants: disabled, qres, fullres.
    * `ldkfs` (h264_nvenc, :int): Low delay key frame scale; Specifies the Scene Change frame size increase allowed in case of single frame VBV and CBR (from 0 to 255) (default 0)
    * `extra_sei` (h264_nvenc, :boolean): Pass on extra SEI data (e.g. a53 cc) to be included in the bitstream (default true)
    * `udu_sei` (h264_nvenc, :boolean): Pass on user data unregistered SEI if available (default false)
    * `intra-refresh` (h264_nvenc, :boolean): Use Periodic Intra Refresh instead of IDR frames (default false)
    * `single-slice-intra-refresh` (h264_nvenc, :boolean): Use single slice intra refresh (default false)
    * `max_slice_size` (h264_nvenc, :int): Maximum encoded slice size in bytes (from 0 to INT_MAX) (default 0)
    * `constrained-encoding` (h264_nvenc, :boolean): Enable constrainedFrame encoding where each slice in the constrained picture is independent of other slices (default false)
    * `lookahead_level` (h264_nvenc, :int): Specifies the lookahead level. Higher level may improve quality at the expense of performance. (from -1 to 15) (default -1) Reported constants: auto, 0, 1, 2, 3.
    * `b` (AVCodecContext, :int64): set bitrate (in bits/s) (from 0 to I64_MAX) (default 200000)
    * `flags` (AVCodecContext, :flags): (default 0) Reported constants: unaligned, mv4, qpel, loop, gray, psnr, ildct, low_delay, global_header, bitexact, aic, ilme, cgop, output_corrupt, drop_changed.
    * `flags2` (AVCodecContext, :flags): (default 0) Reported constants: fast, noout, ignorecrop, local_header, chunks, showall, export_mvs, skip_manual, ass_ro_flush_noop, icc_profiles.
    * `g` (AVCodecContext, :int): set the group of picture (GOP) size (from INT_MIN to INT_MAX) (default 12)
    * `strict` (AVCodecContext, :int): how strictly to follow the standards (from INT_MIN to INT_MAX) (default normal) Reported constants: very, strict, normal, unofficial, experimental.
    * `err_detect` (AVCodecContext, :flags): set error detection flags (default 0) Reported constants: crccheck, bitstream, buffer, explode, ignore_err, careful, compliant, aggressive.
    * `maxrate` (AVCodecContext, :int64): maximum bitrate (in bits/s). Used for VBV together with bufsize. (from 0 to INT_MAX) (default 0)
    * `minrate` (AVCodecContext, :int64): minimum bitrate (in bits/s). Most useful in setting up a CBR encode. It is of little use otherwise. (from INT_MIN to INT_MAX) (default 0)
    * `bufsize` (AVCodecContext, :int): set ratecontrol buffer size (in bits) (from INT_MIN to INT_MAX) (default 0)
    * `global_quality` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default 0)
    * `threads` (AVCodecContext, :int): set the number of threads (from 0 to INT_MAX) (default 1) Reported constants: auto.
    * `profile` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default unknown) Reported constants: unknown, main10.
    * `level` (AVCodecContext, :int): encoding level, usually corresponding to the profile level, codec-specific (from INT_MIN to INT_MAX) (default unknown) Reported constants: unknown.
    * `compression_level` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default -1)
    * `thread_type` (AVCodecContext, :flags): select multithreading type (default slice+frame) Reported constants: slice, frame.
  """
  @spec h264_nvenc(Command.source(), [h264_nvenc_option()]) :: Mapping.t()
  def h264_nvenc(source, options \\ []) do
    options = Options.normalize!(options, @h264_nvenc_schema, "h264_nvenc encoder")
    named(source, "h264_nvenc", options)
  end

  @aac_schema %{
    "aac_coder" => [%{type: :int, constants: ["anmr", "twoloop", "fast"]}],
    "aac_is" => [%{type: :boolean, constants: []}],
    "aac_ltp" => [%{type: :boolean, constants: []}],
    "aac_ms" => [%{type: :boolean, constants: []}],
    "aac_pce" => [%{type: :boolean, constants: []}],
    "aac_pns" => [%{type: :boolean, constants: []}],
    "aac_pred" => [%{type: :boolean, constants: []}],
    "aac_tns" => [%{type: :boolean, constants: []}],
    "b" => [%{type: :int64, constants: []}],
    "bufsize" => [%{type: :int, constants: []}],
    "compression_level" => [%{type: :int, constants: []}],
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
    "global_quality" => [%{type: :int, constants: []}],
    "level" => [%{type: :int, constants: ["unknown"]}],
    "maxrate" => [%{type: :int64, constants: []}],
    "minrate" => [%{type: :int64, constants: []}],
    "profile" => [%{type: :int, constants: ["unknown", "main10"]}],
    "strict" => [
      %{type: :int, constants: ["very", "strict", "normal", "unofficial", "experimental"]}
    ],
    "thread_type" => [%{type: :flags, constants: ["slice", "frame"]}],
    "threads" => [%{type: :int, constants: ["auto"]}]
  }
  @type aac_option ::
          {:aac_coder,
           integer() | String.t() | :anmr | :twoloop | :fast | Command.option_callback()}
          | {:aac_is, boolean() | :auto | String.t() | Command.option_callback()}
          | {:aac_ltp, boolean() | :auto | String.t() | Command.option_callback()}
          | {:aac_ms, boolean() | :auto | String.t() | Command.option_callback()}
          | {:aac_pce, boolean() | :auto | String.t() | Command.option_callback()}
          | {:aac_pns, boolean() | :auto | String.t() | Command.option_callback()}
          | {:aac_pred, boolean() | :auto | String.t() | Command.option_callback()}
          | {:aac_tns, boolean() | :auto | String.t() | Command.option_callback()}
          | {:b, integer() | String.t() | Command.option_callback()}
          | {:bufsize, integer() | String.t() | Command.option_callback()}
          | {:compression_level, integer() | String.t() | Command.option_callback()}
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
             | :aggressive
             | Command.option_callback()}
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
             | :drop_changed
             | Command.option_callback()}
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
             | :icc_profiles
             | Command.option_callback()}
          | {:global_quality, integer() | String.t() | Command.option_callback()}
          | {:level, integer() | String.t() | :unknown | Command.option_callback()}
          | {:maxrate, integer() | String.t() | Command.option_callback()}
          | {:minrate, integer() | String.t() | Command.option_callback()}
          | {:profile, integer() | String.t() | :unknown | :main10 | Command.option_callback()}
          | {:strict,
             integer()
             | String.t()
             | :very
             | :strict
             | :normal
             | :unofficial
             | :experimental
             | Command.option_callback()}
          | {:thread_type,
             integer()
             | String.t()
             | [String.t() | :slice | :frame]
             | :slice
             | :frame
             | Command.option_callback()}
          | {:threads, integer() | String.t() | :auto | Command.option_callback()}
          | {:raw, [Command.output_av_option()]}
  @doc """
  aac: AAC (Advanced Audio Coding)

  Maps one source to an independent encoded output stream.

    * General capabilities: dr1 delay small
    * Threading capabilities: none
    * Supported sample rates: 96000 88200 64000 48000 44100 32000 24000 22050 16000 12000 11025 8000 7350
    * Supported sample formats: fltp

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `aac_coder` (AAC encoder, :int): Coding algorithm (from 0 to 2) (default twoloop) Reported constants: anmr, twoloop, fast.
    * `aac_ms` (AAC encoder, :boolean): Force M/S stereo coding (default auto)
    * `aac_is` (AAC encoder, :boolean): Intensity stereo coding (default true)
    * `aac_pns` (AAC encoder, :boolean): Perceptual noise substitution (default true)
    * `aac_tns` (AAC encoder, :boolean): Temporal noise shaping (default true)
    * `aac_ltp` (AAC encoder, :boolean): Long term prediction (default false)
    * `aac_pred` (AAC encoder, :boolean): AAC-Main prediction (default false)
    * `aac_pce` (AAC encoder, :boolean): Forces the use of PCEs (default false)
    * `b` (AVCodecContext, :int64): set bitrate (in bits/s) (from 0 to I64_MAX) (default 200000)
    * `flags` (AVCodecContext, :flags): (default 0) Reported constants: unaligned, mv4, qpel, loop, gray, psnr, ildct, low_delay, global_header, bitexact, aic, ilme, cgop, output_corrupt, drop_changed.
    * `flags2` (AVCodecContext, :flags): (default 0) Reported constants: fast, noout, ignorecrop, local_header, chunks, showall, export_mvs, skip_manual, ass_ro_flush_noop, icc_profiles.
    * `strict` (AVCodecContext, :int): how strictly to follow the standards (from INT_MIN to INT_MAX) (default normal) Reported constants: very, strict, normal, unofficial, experimental.
    * `err_detect` (AVCodecContext, :flags): set error detection flags (default 0) Reported constants: crccheck, bitstream, buffer, explode, ignore_err, careful, compliant, aggressive.
    * `maxrate` (AVCodecContext, :int64): maximum bitrate (in bits/s). Used for VBV together with bufsize. (from 0 to INT_MAX) (default 0)
    * `minrate` (AVCodecContext, :int64): minimum bitrate (in bits/s). Most useful in setting up a CBR encode. It is of little use otherwise. (from INT_MIN to INT_MAX) (default 0)
    * `bufsize` (AVCodecContext, :int): set ratecontrol buffer size (in bits) (from INT_MIN to INT_MAX) (default 0)
    * `global_quality` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default 0)
    * `threads` (AVCodecContext, :int): set the number of threads (from 0 to INT_MAX) (default 1) Reported constants: auto.
    * `profile` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default unknown) Reported constants: unknown, main10.
    * `level` (AVCodecContext, :int): encoding level, usually corresponding to the profile level, codec-specific (from INT_MIN to INT_MAX) (default unknown) Reported constants: unknown.
    * `compression_level` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default -1)
    * `thread_type` (AVCodecContext, :flags): select multithreading type (default slice+frame) Reported constants: slice, frame.
  """
  @spec aac(Command.source(), [aac_option()]) :: Mapping.t()
  def aac(source, options \\ []) do
    options = Options.normalize!(options, @aac_schema, "aac encoder")
    named(source, "aac", options)
  end

  @libopus_schema %{
    "application" => [%{type: :int, constants: ["voip", "audio", "lowdelay"]}],
    "apply_phase_inv" => [%{type: :boolean, constants: []}],
    "b" => [%{type: :int64, constants: []}],
    "bufsize" => [%{type: :int, constants: []}],
    "compression_level" => [%{type: :int, constants: []}],
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
    "fec" => [%{type: :boolean, constants: []}],
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
    "frame_duration" => [%{type: :float, constants: []}],
    "global_quality" => [%{type: :int, constants: []}],
    "level" => [%{type: :int, constants: ["unknown"]}],
    "mapping_family" => [%{type: :int, constants: []}],
    "maxrate" => [%{type: :int64, constants: []}],
    "minrate" => [%{type: :int64, constants: []}],
    "packet_loss" => [%{type: :int, constants: []}],
    "profile" => [%{type: :int, constants: ["unknown", "main10"]}],
    "strict" => [
      %{type: :int, constants: ["very", "strict", "normal", "unofficial", "experimental"]}
    ],
    "thread_type" => [%{type: :flags, constants: ["slice", "frame"]}],
    "threads" => [%{type: :int, constants: ["auto"]}],
    "vbr" => [%{type: :int, constants: ["off", "on", "constrained"]}]
  }
  @type libopus_option ::
          {:application,
           integer() | String.t() | :voip | :audio | :lowdelay | Command.option_callback()}
          | {:apply_phase_inv, boolean() | :auto | String.t() | Command.option_callback()}
          | {:b, integer() | String.t() | Command.option_callback()}
          | {:bufsize, integer() | String.t() | Command.option_callback()}
          | {:compression_level, integer() | String.t() | Command.option_callback()}
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
             | :aggressive
             | Command.option_callback()}
          | {:fec, boolean() | :auto | String.t() | Command.option_callback()}
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
             | :drop_changed
             | Command.option_callback()}
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
             | :icc_profiles
             | Command.option_callback()}
          | {:frame_duration, number() | String.t() | Command.option_callback()}
          | {:global_quality, integer() | String.t() | Command.option_callback()}
          | {:level, integer() | String.t() | :unknown | Command.option_callback()}
          | {:mapping_family, integer() | String.t() | Command.option_callback()}
          | {:maxrate, integer() | String.t() | Command.option_callback()}
          | {:minrate, integer() | String.t() | Command.option_callback()}
          | {:packet_loss, integer() | String.t() | Command.option_callback()}
          | {:profile, integer() | String.t() | :unknown | :main10 | Command.option_callback()}
          | {:strict,
             integer()
             | String.t()
             | :very
             | :strict
             | :normal
             | :unofficial
             | :experimental
             | Command.option_callback()}
          | {:thread_type,
             integer()
             | String.t()
             | [String.t() | :slice | :frame]
             | :slice
             | :frame
             | Command.option_callback()}
          | {:threads, integer() | String.t() | :auto | Command.option_callback()}
          | {:vbr, integer() | String.t() | :off | :on | :constrained | Command.option_callback()}
          | {:raw, [Command.output_av_option()]}
  @doc """
  libopus: libopus Opus

  Maps one source to an independent encoded output stream.

    * General capabilities: dr1 delay small
    * Threading capabilities: none
    * Supported sample rates: 48000 24000 16000 12000 8000
    * Supported sample formats: s16 flt

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `application` (libopus, :int): Intended application type (from 2048 to 2051) (default audio) Reported constants: voip, audio, lowdelay.
    * `frame_duration` (libopus, :float): Duration of a frame in milliseconds (from 2.5 to 120) (default 20)
    * `packet_loss` (libopus, :int): Expected packet loss percentage (from 0 to 100) (default 0)
    * `fec` (libopus, :boolean): Enable inband FEC. Expected packet loss must be non-zero (default false)
    * `vbr` (libopus, :int): Variable bit rate mode (from 0 to 2) (default on) Reported constants: off, on, constrained.
    * `mapping_family` (libopus, :int): Channel Mapping Family (from -1 to 255) (default -1)
    * `apply_phase_inv` (libopus, :boolean): Apply intensity stereo phase inversion (default true)
    * `b` (AVCodecContext, :int64): set bitrate (in bits/s) (from 0 to I64_MAX) (default 200000)
    * `flags` (AVCodecContext, :flags): (default 0) Reported constants: unaligned, mv4, qpel, loop, gray, psnr, ildct, low_delay, global_header, bitexact, aic, ilme, cgop, output_corrupt, drop_changed.
    * `flags2` (AVCodecContext, :flags): (default 0) Reported constants: fast, noout, ignorecrop, local_header, chunks, showall, export_mvs, skip_manual, ass_ro_flush_noop, icc_profiles.
    * `strict` (AVCodecContext, :int): how strictly to follow the standards (from INT_MIN to INT_MAX) (default normal) Reported constants: very, strict, normal, unofficial, experimental.
    * `err_detect` (AVCodecContext, :flags): set error detection flags (default 0) Reported constants: crccheck, bitstream, buffer, explode, ignore_err, careful, compliant, aggressive.
    * `maxrate` (AVCodecContext, :int64): maximum bitrate (in bits/s). Used for VBV together with bufsize. (from 0 to INT_MAX) (default 0)
    * `minrate` (AVCodecContext, :int64): minimum bitrate (in bits/s). Most useful in setting up a CBR encode. It is of little use otherwise. (from INT_MIN to INT_MAX) (default 0)
    * `bufsize` (AVCodecContext, :int): set ratecontrol buffer size (in bits) (from INT_MIN to INT_MAX) (default 0)
    * `global_quality` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default 0)
    * `threads` (AVCodecContext, :int): set the number of threads (from 0 to INT_MAX) (default 1) Reported constants: auto.
    * `profile` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default unknown) Reported constants: unknown, main10.
    * `level` (AVCodecContext, :int): encoding level, usually corresponding to the profile level, codec-specific (from INT_MIN to INT_MAX) (default unknown) Reported constants: unknown.
    * `compression_level` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default -1)
    * `thread_type` (AVCodecContext, :flags): select multithreading type (default slice+frame) Reported constants: slice, frame.
  """
  @spec libopus(Command.source(), [libopus_option()]) :: Mapping.t()
  def libopus(source, options \\ []) do
    options = Options.normalize!(options, @libopus_schema, "libopus encoder")
    named(source, "libopus", options)
  end

  @mpeg4_schema %{
    "luma_elim_threshold" => [%{type: :int, constants: []}],
    "intra_penalty" => [%{type: :int, constants: []}],
    "data_partitioning" => [%{type: :boolean, constants: []}],
    "compression_level" => [%{type: :int, constants: []}],
    "mpv_flags" => [
      %{type: :flags, constants: ["skip_rd", "strict_gop", "qp_rd", "cbp_rd", "naq", "mv0"]}
    ],
    "chroma_elim_threshold" => [%{type: :int, constants: []}],
    "mepre" => [%{type: :int, constants: []}],
    "border_mask" => [%{type: :float, constants: []}],
    "level" => [%{type: :int, constants: ["unknown"]}],
    "b" => [%{type: :int64, constants: []}],
    "rc_init_cplx" => [%{type: :float, constants: []}],
    "threads" => [%{type: :int, constants: ["auto"]}],
    "lmax" => [%{type: :int, constants: []}],
    "quantizer_noise_shaping" => [%{type: :int, constants: []}],
    "bufsize" => [%{type: :int, constants: []}],
    "rc_eq" => [%{type: :string, constants: []}],
    "rc_qmod_amp" => [%{type: :float, constants: []}],
    "global_quality" => [%{type: :int, constants: []}],
    "skip_factor" => [%{type: :int, constants: []}],
    "brd_scale" => [%{type: :int, constants: []}],
    "error_rate" => [%{type: :int, constants: []}],
    "rc_buf_aggressivity" => [%{type: :float, constants: []}],
    "strict" => [
      %{type: :int, constants: ["very", "strict", "normal", "unofficial", "experimental"]}
    ],
    "lmin" => [%{type: :int, constants: []}],
    "qsquish" => [%{type: :float, constants: []}],
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
    "rc_qmod_freq" => [%{type: :int, constants: []}],
    "sc_threshold" => [%{type: :int, constants: []}],
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
    "ps" => [%{type: :int, constants: []}],
    "alternate_scan" => [%{type: :boolean, constants: []}],
    "g" => [%{type: :int, constants: []}],
    "profile" => [%{type: :int, constants: ["unknown", "main10"]}],
    "noise_reduction" => [%{type: :int, constants: []}],
    "skip_cmp" => [
      %{
        type: :int,
        constants: [
          "sad",
          "sse",
          "satd",
          "dct",
          "psnr",
          "bit",
          "rd",
          "zero",
          "vsad",
          "vsse",
          "nsse",
          "dct264",
          "dctmax",
          "chroma",
          "msad"
        ]
      }
    ],
    "b_sensitivity" => [%{type: :int, constants: []}],
    "minrate" => [%{type: :int64, constants: []}],
    "b_strategy" => [%{type: :int, constants: []}],
    "maxrate" => [%{type: :int64, constants: []}],
    "mepc" => [%{type: :int, constants: []}],
    "thread_type" => [%{type: :flags, constants: ["slice", "frame"]}],
    "skip_threshold" => [%{type: :int, constants: []}],
    "motion_est" => [%{type: :int, constants: ["zero", "epzs", "xone"]}],
    "mpeg_quant" => [%{type: :int, constants: []}],
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
    "skip_exp" => [%{type: :int, constants: []}]
  }
  @type mpeg4_option ::
          {:alternate_scan, boolean() | :auto | String.t() | Command.option_callback()}
          | {:b, integer() | String.t() | Command.option_callback()}
          | {:b_sensitivity, integer() | String.t() | Command.option_callback()}
          | {:b_strategy, integer() | String.t() | Command.option_callback()}
          | {:border_mask, number() | String.t() | Command.option_callback()}
          | {:brd_scale, integer() | String.t() | Command.option_callback()}
          | {:bufsize, integer() | String.t() | Command.option_callback()}
          | {:chroma_elim_threshold, integer() | String.t() | Command.option_callback()}
          | {:compression_level, integer() | String.t() | Command.option_callback()}
          | {:data_partitioning, boolean() | :auto | String.t() | Command.option_callback()}
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
             | :aggressive
             | Command.option_callback()}
          | {:error_rate, integer() | String.t() | Command.option_callback()}
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
             | :drop_changed
             | Command.option_callback()}
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
             | :icc_profiles
             | Command.option_callback()}
          | {:g, integer() | String.t() | Command.option_callback()}
          | {:global_quality, integer() | String.t() | Command.option_callback()}
          | {:intra_penalty, integer() | String.t() | Command.option_callback()}
          | {:level, integer() | String.t() | :unknown | Command.option_callback()}
          | {:lmax, integer() | String.t() | Command.option_callback()}
          | {:lmin, integer() | String.t() | Command.option_callback()}
          | {:luma_elim_threshold, integer() | String.t() | Command.option_callback()}
          | {:maxrate, integer() | String.t() | Command.option_callback()}
          | {:mepc, integer() | String.t() | Command.option_callback()}
          | {:mepre, integer() | String.t() | Command.option_callback()}
          | {:minrate, integer() | String.t() | Command.option_callback()}
          | {:motion_est,
             integer() | String.t() | :zero | :epzs | :xone | Command.option_callback()}
          | {:mpeg_quant, integer() | String.t() | Command.option_callback()}
          | {:mpv_flags,
             integer()
             | String.t()
             | [String.t() | :skip_rd | :strict_gop | :qp_rd | :cbp_rd | :naq | :mv0]
             | :skip_rd
             | :strict_gop
             | :qp_rd
             | :cbp_rd
             | :naq
             | :mv0
             | Command.option_callback()}
          | {:noise_reduction, integer() | String.t() | Command.option_callback()}
          | {:profile, integer() | String.t() | :unknown | :main10 | Command.option_callback()}
          | {:ps, integer() | String.t() | Command.option_callback()}
          | {:qsquish, number() | String.t() | Command.option_callback()}
          | {:quantizer_noise_shaping, integer() | String.t() | Command.option_callback()}
          | {:rc_buf_aggressivity, number() | String.t() | Command.option_callback()}
          | {:rc_eq, String.t() | atom() | Command.option_callback()}
          | {:rc_init_cplx, number() | String.t() | Command.option_callback()}
          | {:rc_qmod_amp, number() | String.t() | Command.option_callback()}
          | {:rc_qmod_freq, integer() | String.t() | Command.option_callback()}
          | {:sc_threshold, integer() | String.t() | Command.option_callback()}
          | {:skip_cmp,
             integer()
             | String.t()
             | :sad
             | :sse
             | :satd
             | :dct
             | :psnr
             | :bit
             | :rd
             | :zero
             | :vsad
             | :vsse
             | :nsse
             | :dct264
             | :dctmax
             | :chroma
             | :msad
             | Command.option_callback()}
          | {:skip_exp, integer() | String.t() | Command.option_callback()}
          | {:skip_factor, integer() | String.t() | Command.option_callback()}
          | {:skip_threshold, integer() | String.t() | Command.option_callback()}
          | {:strict,
             integer()
             | String.t()
             | :very
             | :strict
             | :normal
             | :unofficial
             | :experimental
             | Command.option_callback()}
          | {:thread_type,
             integer()
             | String.t()
             | [String.t() | :slice | :frame]
             | :slice
             | :frame
             | Command.option_callback()}
          | {:threads, integer() | String.t() | :auto | Command.option_callback()}
          | {:raw, [Command.output_av_option()]}
  @doc """
  mpeg4: MPEG-4 part 2

  Maps one source to an independent encoded output stream.

    * General capabilities: delay threads
    * Threading capabilities: slice
    * Supported pixel formats: yuv420p

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `data_partitioning` (MPEG4 encoder, :boolean): Use data partitioning. (default false)
    * `alternate_scan` (MPEG4 encoder, :boolean): Enable alternate scantable. (default false)
    * `mpeg_quant` (MPEG4 encoder, :int): Use MPEG quantizers instead of H.263 (from 0 to 1) (default 0)
    * `b_strategy` (MPEG4 encoder, :int): Strategy to choose between I/P/B-frames (from 0 to 2) (default 0)
    * `b_sensitivity` (MPEG4 encoder, :int): Adjust sensitivity of b_frame_strategy 1 (from 1 to INT_MAX) (default 40)
    * `brd_scale` (MPEG4 encoder, :int): Downscale frames for dynamic B-frame decision (from 0 to 3) (default 0)
    * `mpv_flags` (MPEG4 encoder, :flags): Flags common for all mpegvideo-based encoders. (default 0) Reported constants: skip_rd, strict_gop, qp_rd, cbp_rd, naq, mv0.
    * `luma_elim_threshold` (MPEG4 encoder, :int): single coefficient elimination threshold for luminance (negative values also consider dc coefficient) (from INT_MIN to INT_MAX) (default 0)
    * `chroma_elim_threshold` (MPEG4 encoder, :int): single coefficient elimination threshold for chrominance (negative values also consider dc coefficient) (from INT_MIN to INT_MAX) (default 0)
    * `quantizer_noise_shaping` (MPEG4 encoder, :int): (from 0 to INT_MAX) (default 0)
    * `error_rate` (MPEG4 encoder, :int): Simulate errors in the bitstream to test error concealment. (from 0 to INT_MAX) (default 0)
    * `qsquish` (MPEG4 encoder, :float): how to keep quantizer between qmin and qmax (0 = clip, 1 = use differentiable function) (from 0 to 99) (default 0)
    * `rc_qmod_amp` (MPEG4 encoder, :float): experimental quantizer modulation (from -FLT_MAX to FLT_MAX) (default 0)
    * `rc_qmod_freq` (MPEG4 encoder, :int): experimental quantizer modulation (from INT_MIN to INT_MAX) (default 0)
    * `rc_eq` (MPEG4 encoder, :string): Set rate control equation. When computing the expression, besides the standard functions defined in the section 'Expression Evaluation', the following functions are available: bits2qp(bits), qp2bits(qp). Also the following constants are available: iTex pTex tex mv fCode iCount mcVar var isI isP isB avgQP qComp avgIITex avgPITex avgPPTex avgBPTex avgTex.
    * `rc_init_cplx` (MPEG4 encoder, :float): initial complexity for 1-pass encoding (from -FLT_MAX to FLT_MAX) (default 0)
    * `rc_buf_aggressivity` (MPEG4 encoder, :float): currently useless (from -FLT_MAX to FLT_MAX) (default 1)
    * `border_mask` (MPEG4 encoder, :float): increase the quantizer for macroblocks close to borders (from -FLT_MAX to FLT_MAX) (default 0)
    * `lmin` (MPEG4 encoder, :int): minimum Lagrange factor (VBR) (from 0 to INT_MAX) (default 236)
    * `lmax` (MPEG4 encoder, :int): maximum Lagrange factor (VBR) (from 0 to INT_MAX) (default 3658)
    * `skip_threshold` (MPEG4 encoder, :int): Frame skip threshold (from INT_MIN to INT_MAX) (default 0)
    * `skip_factor` (MPEG4 encoder, :int): Frame skip factor (from INT_MIN to INT_MAX) (default 0)
    * `skip_exp` (MPEG4 encoder, :int): Frame skip exponent (from INT_MIN to INT_MAX) (default 0)
    * `skip_cmp` (MPEG4 encoder, :int): Frame skip compare function (from INT_MIN to INT_MAX) (default dctmax) Reported constants: sad, sse, satd, dct, psnr, bit, rd, zero, vsad, vsse, nsse, dct264, dctmax, chroma, msad.
    * `sc_threshold` (MPEG4 encoder, :int): Scene change threshold (from INT_MIN to INT_MAX) (default 0)
    * `noise_reduction` (MPEG4 encoder, :int): Noise reduction (from INT_MIN to INT_MAX) (default 0)
    * `ps` (MPEG4 encoder, :int): RTP payload size in bytes (from INT_MIN to INT_MAX) (default 0)
    * `motion_est` (MPEG4 encoder, :int): motion estimation algorithm (from 0 to 2) (default epzs) Reported constants: zero, epzs, xone.
    * `mepc` (MPEG4 encoder, :int): Motion estimation bitrate penalty compensation (1.0 = 256) (from INT_MIN to INT_MAX) (default 256)
    * `mepre` (MPEG4 encoder, :int): pre motion estimation (from INT_MIN to INT_MAX) (default 0)
    * `intra_penalty` (MPEG4 encoder, :int): Penalty for intra blocks in block decision (from 0 to 1.07374e+09) (default 0)
    * `b` (AVCodecContext, :int64): set bitrate (in bits/s) (from 0 to I64_MAX) (default 200000)
    * `flags` (AVCodecContext, :flags): (default 0) Reported constants: unaligned, mv4, qpel, loop, gray, psnr, ildct, low_delay, global_header, bitexact, aic, ilme, cgop, output_corrupt, drop_changed.
    * `flags2` (AVCodecContext, :flags): (default 0) Reported constants: fast, noout, ignorecrop, local_header, chunks, showall, export_mvs, skip_manual, ass_ro_flush_noop, icc_profiles.
    * `g` (AVCodecContext, :int): set the group of picture (GOP) size (from INT_MIN to INT_MAX) (default 12)
    * `strict` (AVCodecContext, :int): how strictly to follow the standards (from INT_MIN to INT_MAX) (default normal) Reported constants: very, strict, normal, unofficial, experimental.
    * `err_detect` (AVCodecContext, :flags): set error detection flags (default 0) Reported constants: crccheck, bitstream, buffer, explode, ignore_err, careful, compliant, aggressive.
    * `maxrate` (AVCodecContext, :int64): maximum bitrate (in bits/s). Used for VBV together with bufsize. (from 0 to INT_MAX) (default 0)
    * `minrate` (AVCodecContext, :int64): minimum bitrate (in bits/s). Most useful in setting up a CBR encode. It is of little use otherwise. (from INT_MIN to INT_MAX) (default 0)
    * `bufsize` (AVCodecContext, :int): set ratecontrol buffer size (in bits) (from INT_MIN to INT_MAX) (default 0)
    * `global_quality` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default 0)
    * `threads` (AVCodecContext, :int): set the number of threads (from 0 to INT_MAX) (default 1) Reported constants: auto.
    * `profile` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default unknown) Reported constants: unknown, main10.
    * `level` (AVCodecContext, :int): encoding level, usually corresponding to the profile level, codec-specific (from INT_MIN to INT_MAX) (default unknown) Reported constants: unknown.
    * `compression_level` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default -1)
    * `thread_type` (AVCodecContext, :flags): select multithreading type (default slice+frame) Reported constants: slice, frame.
  """
  @spec mpeg4(Command.source(), [mpeg4_option()]) :: Mapping.t()
  def mpeg4(source, options \\ []) do
    options = Options.normalize!(options, @mpeg4_schema, "mpeg4 encoder")
    named(source, "mpeg4", options)
  end

  @pcm_s16le_schema %{
    "b" => [%{type: :int64, constants: []}],
    "bufsize" => [%{type: :int, constants: []}],
    "compression_level" => [%{type: :int, constants: []}],
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
    "global_quality" => [%{type: :int, constants: []}],
    "level" => [%{type: :int, constants: ["unknown"]}],
    "maxrate" => [%{type: :int64, constants: []}],
    "minrate" => [%{type: :int64, constants: []}],
    "profile" => [%{type: :int, constants: ["unknown", "main10"]}],
    "strict" => [
      %{type: :int, constants: ["very", "strict", "normal", "unofficial", "experimental"]}
    ],
    "thread_type" => [%{type: :flags, constants: ["slice", "frame"]}],
    "threads" => [%{type: :int, constants: ["auto"]}]
  }
  @type pcm_s16le_option ::
          {:b, integer() | String.t() | Command.option_callback()}
          | {:bufsize, integer() | String.t() | Command.option_callback()}
          | {:compression_level, integer() | String.t() | Command.option_callback()}
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
             | :aggressive
             | Command.option_callback()}
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
             | :drop_changed
             | Command.option_callback()}
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
             | :icc_profiles
             | Command.option_callback()}
          | {:global_quality, integer() | String.t() | Command.option_callback()}
          | {:level, integer() | String.t() | :unknown | Command.option_callback()}
          | {:maxrate, integer() | String.t() | Command.option_callback()}
          | {:minrate, integer() | String.t() | Command.option_callback()}
          | {:profile, integer() | String.t() | :unknown | :main10 | Command.option_callback()}
          | {:strict,
             integer()
             | String.t()
             | :very
             | :strict
             | :normal
             | :unofficial
             | :experimental
             | Command.option_callback()}
          | {:thread_type,
             integer()
             | String.t()
             | [String.t() | :slice | :frame]
             | :slice
             | :frame
             | Command.option_callback()}
          | {:threads, integer() | String.t() | :auto | Command.option_callback()}
          | {:raw, [Command.output_av_option()]}
  @doc """
  pcm_s16le: PCM signed 16-bit little-endian

  Maps one source to an independent encoded output stream.

    * General capabilities: dr1 variable
    * Threading capabilities: none
    * Supported sample formats: s16

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `b` (AVCodecContext, :int64): set bitrate (in bits/s) (from 0 to I64_MAX) (default 200000)
    * `flags` (AVCodecContext, :flags): (default 0) Reported constants: unaligned, mv4, qpel, loop, gray, psnr, ildct, low_delay, global_header, bitexact, aic, ilme, cgop, output_corrupt, drop_changed.
    * `flags2` (AVCodecContext, :flags): (default 0) Reported constants: fast, noout, ignorecrop, local_header, chunks, showall, export_mvs, skip_manual, ass_ro_flush_noop, icc_profiles.
    * `strict` (AVCodecContext, :int): how strictly to follow the standards (from INT_MIN to INT_MAX) (default normal) Reported constants: very, strict, normal, unofficial, experimental.
    * `err_detect` (AVCodecContext, :flags): set error detection flags (default 0) Reported constants: crccheck, bitstream, buffer, explode, ignore_err, careful, compliant, aggressive.
    * `maxrate` (AVCodecContext, :int64): maximum bitrate (in bits/s). Used for VBV together with bufsize. (from 0 to INT_MAX) (default 0)
    * `minrate` (AVCodecContext, :int64): minimum bitrate (in bits/s). Most useful in setting up a CBR encode. It is of little use otherwise. (from INT_MIN to INT_MAX) (default 0)
    * `bufsize` (AVCodecContext, :int): set ratecontrol buffer size (in bits) (from INT_MIN to INT_MAX) (default 0)
    * `global_quality` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default 0)
    * `threads` (AVCodecContext, :int): set the number of threads (from 0 to INT_MAX) (default 1) Reported constants: auto.
    * `profile` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default unknown) Reported constants: unknown, main10.
    * `level` (AVCodecContext, :int): encoding level, usually corresponding to the profile level, codec-specific (from INT_MIN to INT_MAX) (default unknown) Reported constants: unknown.
    * `compression_level` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default -1)
    * `thread_type` (AVCodecContext, :flags): select multithreading type (default slice+frame) Reported constants: slice, frame.
  """
  @spec pcm_s16le(Command.source(), [pcm_s16le_option()]) :: Mapping.t()
  def pcm_s16le(source, options \\ []) do
    options = Options.normalize!(options, @pcm_s16le_schema, "pcm_s16le encoder")
    named(source, "pcm_s16le", options)
  end

  @ffv1_schema %{
    "b" => [%{type: :int64, constants: []}],
    "bufsize" => [%{type: :int, constants: []}],
    "coder" => [%{type: :int, constants: ["rice", "range_def", "range_tab", "ac"]}],
    "compression_level" => [%{type: :int, constants: []}],
    "context" => [%{type: :int, constants: []}],
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
    "g" => [%{type: :int, constants: []}],
    "global_quality" => [%{type: :int, constants: []}],
    "level" => [%{type: :int, constants: ["unknown"]}],
    "maxrate" => [%{type: :int64, constants: []}],
    "minrate" => [%{type: :int64, constants: []}],
    "profile" => [%{type: :int, constants: ["unknown", "main10"]}],
    "slicecrc" => [%{type: :boolean, constants: []}],
    "strict" => [
      %{type: :int, constants: ["very", "strict", "normal", "unofficial", "experimental"]}
    ],
    "thread_type" => [%{type: :flags, constants: ["slice", "frame"]}],
    "threads" => [%{type: :int, constants: ["auto"]}]
  }
  @type ffv1_option ::
          {:b, integer() | String.t() | Command.option_callback()}
          | {:bufsize, integer() | String.t() | Command.option_callback()}
          | {:coder,
             integer()
             | String.t()
             | :rice
             | :range_def
             | :range_tab
             | :ac
             | Command.option_callback()}
          | {:compression_level, integer() | String.t() | Command.option_callback()}
          | {:context, integer() | String.t() | Command.option_callback()}
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
             | :aggressive
             | Command.option_callback()}
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
             | :drop_changed
             | Command.option_callback()}
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
             | :icc_profiles
             | Command.option_callback()}
          | {:g, integer() | String.t() | Command.option_callback()}
          | {:global_quality, integer() | String.t() | Command.option_callback()}
          | {:level, integer() | String.t() | :unknown | Command.option_callback()}
          | {:maxrate, integer() | String.t() | Command.option_callback()}
          | {:minrate, integer() | String.t() | Command.option_callback()}
          | {:profile, integer() | String.t() | :unknown | :main10 | Command.option_callback()}
          | {:slicecrc, boolean() | :auto | String.t() | Command.option_callback()}
          | {:strict,
             integer()
             | String.t()
             | :very
             | :strict
             | :normal
             | :unofficial
             | :experimental
             | Command.option_callback()}
          | {:thread_type,
             integer()
             | String.t()
             | [String.t() | :slice | :frame]
             | :slice
             | :frame
             | Command.option_callback()}
          | {:threads, integer() | String.t() | :auto | Command.option_callback()}
          | {:raw, [Command.output_av_option()]}
  @doc """
  ffv1: FFmpeg video codec #1

  Maps one source to an independent encoded output stream.

    * General capabilities: dr1 delay threads
    * Threading capabilities: slice
    * Supported pixel formats: yuv420p yuva420p yuva422p yuv444p yuva444p yuv440p yuv422p yuv411p yuv410p bgr0 bgra yuv420p16le yuv422p16le yuv444p16le yuv444p9le yuv422p9le yuv420p9le yuv420p10le yuv422p10le yuv444p10le yuv420p12le yuv422p12le yuv444p12le yuva444p16le yuva422p16le yuva420p16le yuva444p12le yuva422p12le yuva444p10le yuva422p10le yuva420p10le yuva444p9le yuva422p9le yuva420p9le gray16le gray gbrp9le gbrp10le gbrp12le gbrp14le gbrap14le gbrap10le gbrap12le ya8 gray10le gray12le gray14le gbrp16le rgb48le gbrap16le rgba64le gray9le yuv420p14le yuv422p14le yuv444p14le yuv440p10le yuv440p12le

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `slicecrc` (ffv1 encoder, :boolean): Protect slices with CRCs (default auto)
    * `coder` (ffv1 encoder, :int): Coder type (from -2 to 2) (default rice) Reported constants: rice, range_def, range_tab, ac.
    * `context` (ffv1 encoder, :int): Context model (from 0 to 1) (default 0)
    * `b` (AVCodecContext, :int64): set bitrate (in bits/s) (from 0 to I64_MAX) (default 200000)
    * `flags` (AVCodecContext, :flags): (default 0) Reported constants: unaligned, mv4, qpel, loop, gray, psnr, ildct, low_delay, global_header, bitexact, aic, ilme, cgop, output_corrupt, drop_changed.
    * `flags2` (AVCodecContext, :flags): (default 0) Reported constants: fast, noout, ignorecrop, local_header, chunks, showall, export_mvs, skip_manual, ass_ro_flush_noop, icc_profiles.
    * `g` (AVCodecContext, :int): set the group of picture (GOP) size (from INT_MIN to INT_MAX) (default 12)
    * `strict` (AVCodecContext, :int): how strictly to follow the standards (from INT_MIN to INT_MAX) (default normal) Reported constants: very, strict, normal, unofficial, experimental.
    * `err_detect` (AVCodecContext, :flags): set error detection flags (default 0) Reported constants: crccheck, bitstream, buffer, explode, ignore_err, careful, compliant, aggressive.
    * `maxrate` (AVCodecContext, :int64): maximum bitrate (in bits/s). Used for VBV together with bufsize. (from 0 to INT_MAX) (default 0)
    * `minrate` (AVCodecContext, :int64): minimum bitrate (in bits/s). Most useful in setting up a CBR encode. It is of little use otherwise. (from INT_MIN to INT_MAX) (default 0)
    * `bufsize` (AVCodecContext, :int): set ratecontrol buffer size (in bits) (from INT_MIN to INT_MAX) (default 0)
    * `global_quality` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default 0)
    * `threads` (AVCodecContext, :int): set the number of threads (from 0 to INT_MAX) (default 1) Reported constants: auto.
    * `profile` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default unknown) Reported constants: unknown, main10.
    * `level` (AVCodecContext, :int): encoding level, usually corresponding to the profile level, codec-specific (from INT_MIN to INT_MAX) (default unknown) Reported constants: unknown.
    * `compression_level` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default -1)
    * `thread_type` (AVCodecContext, :flags): select multithreading type (default slice+frame) Reported constants: slice, frame.
  """
  @spec ffv1(Command.source(), [ffv1_option()]) :: Mapping.t()
  def ffv1(source, options \\ []) do
    options = Options.normalize!(options, @ffv1_schema, "ffv1 encoder")
    named(source, "ffv1", options)
  end

  @png_schema %{
    "b" => [%{type: :int64, constants: []}],
    "bufsize" => [%{type: :int, constants: []}],
    "compression_level" => [%{type: :int, constants: []}],
    "dpi" => [%{type: :int, constants: []}],
    "dpm" => [%{type: :int, constants: []}],
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
    "g" => [%{type: :int, constants: []}],
    "global_quality" => [%{type: :int, constants: []}],
    "level" => [%{type: :int, constants: ["unknown"]}],
    "maxrate" => [%{type: :int64, constants: []}],
    "minrate" => [%{type: :int64, constants: []}],
    "pred" => [%{type: :int, constants: ["none", "sub", "up", "avg", "paeth", "mixed"]}],
    "profile" => [%{type: :int, constants: ["unknown", "main10"]}],
    "strict" => [
      %{type: :int, constants: ["very", "strict", "normal", "unofficial", "experimental"]}
    ],
    "thread_type" => [%{type: :flags, constants: ["slice", "frame"]}],
    "threads" => [%{type: :int, constants: ["auto"]}]
  }
  @type png_option ::
          {:b, integer() | String.t() | Command.option_callback()}
          | {:bufsize, integer() | String.t() | Command.option_callback()}
          | {:compression_level, integer() | String.t() | Command.option_callback()}
          | {:dpi, integer() | String.t() | Command.option_callback()}
          | {:dpm, integer() | String.t() | Command.option_callback()}
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
             | :aggressive
             | Command.option_callback()}
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
             | :drop_changed
             | Command.option_callback()}
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
             | :icc_profiles
             | Command.option_callback()}
          | {:g, integer() | String.t() | Command.option_callback()}
          | {:global_quality, integer() | String.t() | Command.option_callback()}
          | {:level, integer() | String.t() | :unknown | Command.option_callback()}
          | {:maxrate, integer() | String.t() | Command.option_callback()}
          | {:minrate, integer() | String.t() | Command.option_callback()}
          | {:pred,
             integer()
             | String.t()
             | :none
             | :sub
             | :up
             | :avg
             | :paeth
             | :mixed
             | Command.option_callback()}
          | {:profile, integer() | String.t() | :unknown | :main10 | Command.option_callback()}
          | {:strict,
             integer()
             | String.t()
             | :very
             | :strict
             | :normal
             | :unofficial
             | :experimental
             | Command.option_callback()}
          | {:thread_type,
             integer()
             | String.t()
             | [String.t() | :slice | :frame]
             | :slice
             | :frame
             | Command.option_callback()}
          | {:threads, integer() | String.t() | :auto | Command.option_callback()}
          | {:raw, [Command.output_av_option()]}
  @doc """
  png: PNG (Portable Network Graphics) image

  Maps one source to an independent encoded output stream.

    * General capabilities: dr1 threads
    * Threading capabilities: frame
    * Supported pixel formats: rgb24 rgba rgb48be rgba64be pal8 gray ya8 gray16be ya16be monob

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `dpi` ((A)PNG encoder, :int): Set image resolution (in dots per inch) (from 0 to 65536) (default 0)
    * `dpm` ((A)PNG encoder, :int): Set image resolution (in dots per meter) (from 0 to 65536) (default 0)
    * `pred` ((A)PNG encoder, :int): Prediction method (from 0 to 5) (default none) Reported constants: none, sub, up, avg, paeth, mixed.
    * `b` (AVCodecContext, :int64): set bitrate (in bits/s) (from 0 to I64_MAX) (default 200000)
    * `flags` (AVCodecContext, :flags): (default 0) Reported constants: unaligned, mv4, qpel, loop, gray, psnr, ildct, low_delay, global_header, bitexact, aic, ilme, cgop, output_corrupt, drop_changed.
    * `flags2` (AVCodecContext, :flags): (default 0) Reported constants: fast, noout, ignorecrop, local_header, chunks, showall, export_mvs, skip_manual, ass_ro_flush_noop, icc_profiles.
    * `g` (AVCodecContext, :int): set the group of picture (GOP) size (from INT_MIN to INT_MAX) (default 12)
    * `strict` (AVCodecContext, :int): how strictly to follow the standards (from INT_MIN to INT_MAX) (default normal) Reported constants: very, strict, normal, unofficial, experimental.
    * `err_detect` (AVCodecContext, :flags): set error detection flags (default 0) Reported constants: crccheck, bitstream, buffer, explode, ignore_err, careful, compliant, aggressive.
    * `maxrate` (AVCodecContext, :int64): maximum bitrate (in bits/s). Used for VBV together with bufsize. (from 0 to INT_MAX) (default 0)
    * `minrate` (AVCodecContext, :int64): minimum bitrate (in bits/s). Most useful in setting up a CBR encode. It is of little use otherwise. (from INT_MIN to INT_MAX) (default 0)
    * `bufsize` (AVCodecContext, :int): set ratecontrol buffer size (in bits) (from INT_MIN to INT_MAX) (default 0)
    * `global_quality` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default 0)
    * `threads` (AVCodecContext, :int): set the number of threads (from 0 to INT_MAX) (default 1) Reported constants: auto.
    * `profile` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default unknown) Reported constants: unknown, main10.
    * `level` (AVCodecContext, :int): encoding level, usually corresponding to the profile level, codec-specific (from INT_MIN to INT_MAX) (default unknown) Reported constants: unknown.
    * `compression_level` (AVCodecContext, :int): (from INT_MIN to INT_MAX) (default -1)
    * `thread_type` (AVCodecContext, :flags): select multithreading type (default slice+frame) Reported constants: slice, frame.
  """
  @spec png(Command.source(), [png_option()]) :: Mapping.t()
  def png(source, options \\ []) do
    options = Options.normalize!(options, @png_schema, "png encoder")
    named(source, "png", options)
  end

  # END GENERATED HELPERS
end
