defmodule FFix.Muxer do
  @moduledoc """
  Format-specific output shortcuts and low-level muxer configuration.

  Named helpers return `FFix.Command.Output` declarations. Use `video:`, `audio:`,
  or ordered `sources:` bindings as in `FFix.output/2`. Other top-level options
  configure the muxer. Put raw file-level CLI controls in `output_options:`.

      FFix.Muxer.mp4("out.mp4",
        video: FFix.Encoder.libx264(video, crf: 18),
        movflags: [:faststart],
        output_options: [t: 10]
      )

  The helper forces its named format regardless of the target's extension.
  A declaration can write multiple files, as with HLS or segmenting muxers.
  Keep `FFix.output/2` for automatic format selection or independent muxer values.

  Helpers validate option names and basic values using recorded metadata, not
  live discovery. No reported defaults are emitted. Strings remain open FFmpeg
  values; flag lists are normalized. `raw: [{"new_option", "value"}]` skips
  metadata checks for particular options, not command-structure validation.

  `named/3` handles dynamic formats without a metadata schema. `new/2` builds a
  standalone muxer configuration; a nil name leaves format selection to FFmpeg.
  """

  alias FFix.Command
  alias FFix.Command.Output
  alias FFix.Options

  @type t :: %__MODULE__{name: String.t() | nil, options: [Command.av_option()]}
  defstruct [:name, options: []]

  @doc "Builds an unbound muxer configuration without a metadata schema."
  @spec new(String.t() | nil, [Command.av_option()]) :: t()
  def new(name, options \\ []) do
    Command.validate_component!(%__MODULE__{name: name, options: options})
  end

  @doc "Builds an output for a dynamic muxer name; extra CLI controls go in output_options."
  @spec named(Output.target(), String.t(), list()) :: Output.t()
  def named(target, name, options), do: build_output(target, name, options, nil)

  defp build_output(target, name, options, schema) do
    {bindings, options} = Options.split!(options, [:video, :audio, :sources, :output_options])
    output_options = Keyword.get(bindings, :output_options, [])
    {_special, output_options} = Options.split!(output_options, [])
    muxer_options = Options.normalize!(options, schema, "#{name} muxer")
    output = FFix.output(target, Keyword.drop(bindings, [:output_options]))
    %{output | muxer: new(name, muxer_options), options: output_options}
  end

  # BEGIN GENERATED HELPERS
  @mp4_schema %{
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
    "avoid_negative_ts" => [
      %{type: :int, constants: ["auto", "disabled", "make_non_negative", "make_zero"]}
    ],
    "brand" => [%{type: :string, constants: []}],
    "empty_hdlr_name" => [%{type: :boolean, constants: []}],
    "encryption_key" => [%{type: :binary, constants: []}],
    "encryption_kid" => [%{type: :binary, constants: []}],
    "encryption_scheme" => [%{type: :string, constants: []}],
    "fflags" => [
      %{
        type: :flags,
        constants: [
          "flush_packets",
          "ignidx",
          "genpts",
          "nofillin",
          "noparse",
          "igndts",
          "discardcorrupt",
          "sortdts",
          "fastseek",
          "nobuffer",
          "bitexact",
          "shortest",
          "autobsf"
        ]
      }
    ],
    "flush_packets" => [%{type: :int, constants: []}],
    "frag_duration" => [%{type: :int, constants: []}],
    "frag_interleave" => [%{type: :int, constants: []}],
    "frag_size" => [%{type: :int, constants: []}],
    "fragment_index" => [%{type: :int, constants: []}],
    "iods_audio_profile" => [%{type: :int, constants: []}],
    "iods_video_profile" => [%{type: :int, constants: []}],
    "ism_lookahead" => [%{type: :int, constants: []}],
    "max_delay" => [%{type: :int, constants: []}],
    "min_frag_duration" => [%{type: :int, constants: []}],
    "moov_size" => [%{type: :int, constants: []}],
    "mov_gamma" => [%{type: :float, constants: []}],
    "movflags" => [
      %{
        type: :flags,
        constants: [
          "cmaf",
          "dash",
          "default_base_moof",
          "delay_moov",
          "disable_chpl",
          "empty_moov",
          "faststart",
          "frag_custom",
          "frag_discont",
          "frag_every_frame",
          "frag_keyframe",
          "global_sidx",
          "isml",
          "negative_cts_offsets",
          "omit_tfhd_offset",
          "prefer_icc",
          "rtphint",
          "separate_moof",
          "skip_sidx",
          "skip_trailer",
          "use_metadata_tags",
          "write_colr",
          "write_gama",
          "hybrid_fragmented"
        ]
      }
    ],
    "movie_timescale" => [%{type: :int, constants: []}],
    "rtpflags" => [
      %{type: :flags, constants: ["latm", "rfc2190", "skip_rtcp", "h264_mode0", "send_bye"]}
    ],
    "skip_iods" => [%{type: :boolean, constants: []}],
    "use_editlist" => [%{type: :boolean, constants: []}],
    "use_stream_ids_as_track_ids" => [%{type: :boolean, constants: []}],
    "video_track_timescale" => [%{type: :int, constants: []}],
    "write_btrt" => [%{type: :boolean, constants: []}],
    "write_prft" => [%{type: :int, constants: ["pts", "wallclock"]}],
    "write_tmcd" => [%{type: :boolean, constants: []}]
  }
  @type mp4_option ::
          {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
          | {:avoid_negative_ts,
             integer() | String.t() | :auto | :disabled | :make_non_negative | :make_zero}
          | {:brand, String.t() | atom()}
          | {:empty_hdlr_name, boolean() | :auto | String.t()}
          | {:encryption_key, String.t() | atom()}
          | {:encryption_kid, String.t() | atom()}
          | {:encryption_scheme, String.t() | atom()}
          | {:fflags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :flush_packets
                 | :ignidx
                 | :genpts
                 | :nofillin
                 | :noparse
                 | :igndts
                 | :discardcorrupt
                 | :sortdts
                 | :fastseek
                 | :nobuffer
                 | :bitexact
                 | :shortest
                 | :autobsf
               ]
             | :flush_packets
             | :ignidx
             | :genpts
             | :nofillin
             | :noparse
             | :igndts
             | :discardcorrupt
             | :sortdts
             | :fastseek
             | :nobuffer
             | :bitexact
             | :shortest
             | :autobsf}
          | {:flush_packets, integer() | String.t()}
          | {:frag_duration, integer() | String.t()}
          | {:frag_interleave, integer() | String.t()}
          | {:frag_size, integer() | String.t()}
          | {:fragment_index, integer() | String.t()}
          | {:iods_audio_profile, integer() | String.t()}
          | {:iods_video_profile, integer() | String.t()}
          | {:ism_lookahead, integer() | String.t()}
          | {:max_delay, integer() | String.t()}
          | {:min_frag_duration, integer() | String.t()}
          | {:moov_size, integer() | String.t()}
          | {:mov_gamma, number() | String.t()}
          | {:movflags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :cmaf
                 | :dash
                 | :default_base_moof
                 | :delay_moov
                 | :disable_chpl
                 | :empty_moov
                 | :faststart
                 | :frag_custom
                 | :frag_discont
                 | :frag_every_frame
                 | :frag_keyframe
                 | :global_sidx
                 | :isml
                 | :negative_cts_offsets
                 | :omit_tfhd_offset
                 | :prefer_icc
                 | :rtphint
                 | :separate_moof
                 | :skip_sidx
                 | :skip_trailer
                 | :use_metadata_tags
                 | :write_colr
                 | :write_gama
                 | :hybrid_fragmented
               ]
             | :cmaf
             | :dash
             | :default_base_moof
             | :delay_moov
             | :disable_chpl
             | :empty_moov
             | :faststart
             | :frag_custom
             | :frag_discont
             | :frag_every_frame
             | :frag_keyframe
             | :global_sidx
             | :isml
             | :negative_cts_offsets
             | :omit_tfhd_offset
             | :prefer_icc
             | :rtphint
             | :separate_moof
             | :skip_sidx
             | :skip_trailer
             | :use_metadata_tags
             | :write_colr
             | :write_gama
             | :hybrid_fragmented}
          | {:movie_timescale, integer() | String.t()}
          | {:rtpflags,
             integer()
             | String.t()
             | [String.t() | :latm | :rfc2190 | :skip_rtcp | :h264_mode0 | :send_bye]
             | :latm
             | :rfc2190
             | :skip_rtcp
             | :h264_mode0
             | :send_bye}
          | {:skip_iods, boolean() | :auto | String.t()}
          | {:use_editlist, boolean() | :auto | String.t()}
          | {:use_stream_ids_as_track_ids, boolean() | :auto | String.t()}
          | {:video_track_timescale, integer() | String.t()}
          | {:write_btrt, boolean() | :auto | String.t()}
          | {:write_prft, integer() | String.t() | :pts | :wallclock}
          | {:write_tmcd, boolean() | :auto | String.t()}
          | {:raw, [Command.av_option()]}
          | {:video, Command.mapping() | [Command.mapping()]}
          | {:audio, Command.mapping() | [Command.mapping()]}
          | {:sources, [Command.mapping()]}
          | {:output_options, [Command.option()]}
  @doc """
  mp4: MP4 (MPEG-4 Part 14)

  Builds an output declaration. Pass video/audio or ordered sources; raw CLI controls go in output_options.

    * Common extensions: mp4.
    * Mime type: video/mp4.
    * Default video codec: h264.
    * Default audio codec: aac.

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `brand` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :string): Override major brand
    * `empty_hdlr_name` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :boolean): write zero-length name string in hdlr atoms within mdia and minf atoms (default false)
    * `encryption_key` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :binary): The media encryption key (hex)
    * `encryption_kid` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :binary): The media encryption key identifier (hex)
    * `encryption_scheme` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :string): Configures the encryption scheme, allowed values are none, cenc-aes-ctr
    * `frag_duration` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): Maximum fragment duration (from 0 to INT_MAX) (default 0)
    * `frag_interleave` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): Interleave samples within fragments (max number of consecutive samples, lower is tighter interleaving, but with more overhead) (from 0 to INT_MAX) (default 0)
    * `frag_size` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): Maximum fragment size (from 0 to INT_MAX) (default 0)
    * `fragment_index` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): Fragment number of the next fragment (from 1 to INT_MAX) (default 1)
    * `iods_audio_profile` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): iods audio profile atom. (from -1 to 255) (default -1)
    * `iods_video_profile` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): iods video profile atom. (from -1 to 255) (default -1)
    * `ism_lookahead` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): Number of lookahead entries for ISM files (from 0 to 255) (default 0)
    * `movflags` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :flags): MOV muxer flags (default 0) Reported constants: cmaf, dash, default_base_moof, delay_moov, disable_chpl, empty_moov, faststart, frag_custom, frag_discont, frag_every_frame, frag_keyframe, global_sidx, isml, negative_cts_offsets, omit_tfhd_offset, prefer_icc, rtphint, separate_moof, skip_sidx, skip_trailer, use_metadata_tags, write_colr, write_gama, hybrid_fragmented.
    * `moov_size` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): maximum moov size so it can be placed at the begin (from 0 to INT_MAX) (default 0)
    * `min_frag_duration` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): Minimum fragment duration (from 0 to INT_MAX) (default 0)
    * `mov_gamma` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :float): gamma value for gama atom (from 0 to 10) (default 0)
    * `movie_timescale` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): set movie timescale (from 1 to INT_MAX) (default 1000)
    * `rtpflags` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :flags): RTP muxer flags (default 0) Reported constants: latm, rfc2190, skip_rtcp, h264_mode0, send_bye.
    * `skip_iods` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :boolean): Skip writing iods atom. (default true)
    * `use_editlist` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :boolean): use edit list (default auto)
    * `use_stream_ids_as_track_ids` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :boolean): use stream ids as track ids (default false)
    * `video_track_timescale` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): set timescale of all video tracks (from 0 to INT_MAX) (default 0)
    * `write_btrt` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :boolean): force or disable writing btrt (default auto)
    * `write_prft` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): Write producer reference time box with specified time source (from 0 to 2) (default 0) Reported constants: pts, wallclock.
    * `write_tmcd` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :boolean): force or disable writing tmcd (default auto)
    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
    * `flush_packets` (AVFormatContext, :int): enable flushing of the I/O context after each packet (from -1 to 1) (default -1)
    * `avoid_negative_ts` (AVFormatContext, :int): shift timestamps so they start at 0 (from -1 to 2) (default auto) Reported constants: auto, disabled, make_non_negative, make_zero.
  """
  @spec mp4(Output.target(), [mp4_option()]) :: Output.t()
  def mp4(target, options) do
    build_output(target, "mp4", options, @mp4_schema)
  end

  @mov_schema %{
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
    "avoid_negative_ts" => [
      %{type: :int, constants: ["auto", "disabled", "make_non_negative", "make_zero"]}
    ],
    "brand" => [%{type: :string, constants: []}],
    "empty_hdlr_name" => [%{type: :boolean, constants: []}],
    "encryption_key" => [%{type: :binary, constants: []}],
    "encryption_kid" => [%{type: :binary, constants: []}],
    "encryption_scheme" => [%{type: :string, constants: []}],
    "fflags" => [
      %{
        type: :flags,
        constants: [
          "flush_packets",
          "ignidx",
          "genpts",
          "nofillin",
          "noparse",
          "igndts",
          "discardcorrupt",
          "sortdts",
          "fastseek",
          "nobuffer",
          "bitexact",
          "shortest",
          "autobsf"
        ]
      }
    ],
    "flush_packets" => [%{type: :int, constants: []}],
    "frag_duration" => [%{type: :int, constants: []}],
    "frag_interleave" => [%{type: :int, constants: []}],
    "frag_size" => [%{type: :int, constants: []}],
    "fragment_index" => [%{type: :int, constants: []}],
    "iods_audio_profile" => [%{type: :int, constants: []}],
    "iods_video_profile" => [%{type: :int, constants: []}],
    "ism_lookahead" => [%{type: :int, constants: []}],
    "max_delay" => [%{type: :int, constants: []}],
    "min_frag_duration" => [%{type: :int, constants: []}],
    "moov_size" => [%{type: :int, constants: []}],
    "mov_gamma" => [%{type: :float, constants: []}],
    "movflags" => [
      %{
        type: :flags,
        constants: [
          "cmaf",
          "dash",
          "default_base_moof",
          "delay_moov",
          "disable_chpl",
          "empty_moov",
          "faststart",
          "frag_custom",
          "frag_discont",
          "frag_every_frame",
          "frag_keyframe",
          "global_sidx",
          "isml",
          "negative_cts_offsets",
          "omit_tfhd_offset",
          "prefer_icc",
          "rtphint",
          "separate_moof",
          "skip_sidx",
          "skip_trailer",
          "use_metadata_tags",
          "write_colr",
          "write_gama",
          "hybrid_fragmented"
        ]
      }
    ],
    "movie_timescale" => [%{type: :int, constants: []}],
    "rtpflags" => [
      %{type: :flags, constants: ["latm", "rfc2190", "skip_rtcp", "h264_mode0", "send_bye"]}
    ],
    "skip_iods" => [%{type: :boolean, constants: []}],
    "use_editlist" => [%{type: :boolean, constants: []}],
    "use_stream_ids_as_track_ids" => [%{type: :boolean, constants: []}],
    "video_track_timescale" => [%{type: :int, constants: []}],
    "write_btrt" => [%{type: :boolean, constants: []}],
    "write_prft" => [%{type: :int, constants: ["pts", "wallclock"]}],
    "write_tmcd" => [%{type: :boolean, constants: []}]
  }
  @type mov_option ::
          {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
          | {:avoid_negative_ts,
             integer() | String.t() | :auto | :disabled | :make_non_negative | :make_zero}
          | {:brand, String.t() | atom()}
          | {:empty_hdlr_name, boolean() | :auto | String.t()}
          | {:encryption_key, String.t() | atom()}
          | {:encryption_kid, String.t() | atom()}
          | {:encryption_scheme, String.t() | atom()}
          | {:fflags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :flush_packets
                 | :ignidx
                 | :genpts
                 | :nofillin
                 | :noparse
                 | :igndts
                 | :discardcorrupt
                 | :sortdts
                 | :fastseek
                 | :nobuffer
                 | :bitexact
                 | :shortest
                 | :autobsf
               ]
             | :flush_packets
             | :ignidx
             | :genpts
             | :nofillin
             | :noparse
             | :igndts
             | :discardcorrupt
             | :sortdts
             | :fastseek
             | :nobuffer
             | :bitexact
             | :shortest
             | :autobsf}
          | {:flush_packets, integer() | String.t()}
          | {:frag_duration, integer() | String.t()}
          | {:frag_interleave, integer() | String.t()}
          | {:frag_size, integer() | String.t()}
          | {:fragment_index, integer() | String.t()}
          | {:iods_audio_profile, integer() | String.t()}
          | {:iods_video_profile, integer() | String.t()}
          | {:ism_lookahead, integer() | String.t()}
          | {:max_delay, integer() | String.t()}
          | {:min_frag_duration, integer() | String.t()}
          | {:moov_size, integer() | String.t()}
          | {:mov_gamma, number() | String.t()}
          | {:movflags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :cmaf
                 | :dash
                 | :default_base_moof
                 | :delay_moov
                 | :disable_chpl
                 | :empty_moov
                 | :faststart
                 | :frag_custom
                 | :frag_discont
                 | :frag_every_frame
                 | :frag_keyframe
                 | :global_sidx
                 | :isml
                 | :negative_cts_offsets
                 | :omit_tfhd_offset
                 | :prefer_icc
                 | :rtphint
                 | :separate_moof
                 | :skip_sidx
                 | :skip_trailer
                 | :use_metadata_tags
                 | :write_colr
                 | :write_gama
                 | :hybrid_fragmented
               ]
             | :cmaf
             | :dash
             | :default_base_moof
             | :delay_moov
             | :disable_chpl
             | :empty_moov
             | :faststart
             | :frag_custom
             | :frag_discont
             | :frag_every_frame
             | :frag_keyframe
             | :global_sidx
             | :isml
             | :negative_cts_offsets
             | :omit_tfhd_offset
             | :prefer_icc
             | :rtphint
             | :separate_moof
             | :skip_sidx
             | :skip_trailer
             | :use_metadata_tags
             | :write_colr
             | :write_gama
             | :hybrid_fragmented}
          | {:movie_timescale, integer() | String.t()}
          | {:rtpflags,
             integer()
             | String.t()
             | [String.t() | :latm | :rfc2190 | :skip_rtcp | :h264_mode0 | :send_bye]
             | :latm
             | :rfc2190
             | :skip_rtcp
             | :h264_mode0
             | :send_bye}
          | {:skip_iods, boolean() | :auto | String.t()}
          | {:use_editlist, boolean() | :auto | String.t()}
          | {:use_stream_ids_as_track_ids, boolean() | :auto | String.t()}
          | {:video_track_timescale, integer() | String.t()}
          | {:write_btrt, boolean() | :auto | String.t()}
          | {:write_prft, integer() | String.t() | :pts | :wallclock}
          | {:write_tmcd, boolean() | :auto | String.t()}
          | {:raw, [Command.av_option()]}
          | {:video, Command.mapping() | [Command.mapping()]}
          | {:audio, Command.mapping() | [Command.mapping()]}
          | {:sources, [Command.mapping()]}
          | {:output_options, [Command.option()]}
  @doc """
  mov: QuickTime / MOV

  Builds an output declaration. Pass video/audio or ordered sources; raw CLI controls go in output_options.

    * Common extensions: mov.
    * Default video codec: h264.
    * Default audio codec: aac.

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `brand` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :string): Override major brand
    * `empty_hdlr_name` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :boolean): write zero-length name string in hdlr atoms within mdia and minf atoms (default false)
    * `encryption_key` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :binary): The media encryption key (hex)
    * `encryption_kid` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :binary): The media encryption key identifier (hex)
    * `encryption_scheme` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :string): Configures the encryption scheme, allowed values are none, cenc-aes-ctr
    * `frag_duration` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): Maximum fragment duration (from 0 to INT_MAX) (default 0)
    * `frag_interleave` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): Interleave samples within fragments (max number of consecutive samples, lower is tighter interleaving, but with more overhead) (from 0 to INT_MAX) (default 0)
    * `frag_size` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): Maximum fragment size (from 0 to INT_MAX) (default 0)
    * `fragment_index` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): Fragment number of the next fragment (from 1 to INT_MAX) (default 1)
    * `iods_audio_profile` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): iods audio profile atom. (from -1 to 255) (default -1)
    * `iods_video_profile` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): iods video profile atom. (from -1 to 255) (default -1)
    * `ism_lookahead` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): Number of lookahead entries for ISM files (from 0 to 255) (default 0)
    * `movflags` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :flags): MOV muxer flags (default 0) Reported constants: cmaf, dash, default_base_moof, delay_moov, disable_chpl, empty_moov, faststart, frag_custom, frag_discont, frag_every_frame, frag_keyframe, global_sidx, isml, negative_cts_offsets, omit_tfhd_offset, prefer_icc, rtphint, separate_moof, skip_sidx, skip_trailer, use_metadata_tags, write_colr, write_gama, hybrid_fragmented.
    * `moov_size` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): maximum moov size so it can be placed at the begin (from 0 to INT_MAX) (default 0)
    * `min_frag_duration` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): Minimum fragment duration (from 0 to INT_MAX) (default 0)
    * `mov_gamma` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :float): gamma value for gama atom (from 0 to 10) (default 0)
    * `movie_timescale` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): set movie timescale (from 1 to INT_MAX) (default 1000)
    * `rtpflags` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :flags): RTP muxer flags (default 0) Reported constants: latm, rfc2190, skip_rtcp, h264_mode0, send_bye.
    * `skip_iods` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :boolean): Skip writing iods atom. (default true)
    * `use_editlist` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :boolean): use edit list (default auto)
    * `use_stream_ids_as_track_ids` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :boolean): use stream ids as track ids (default false)
    * `video_track_timescale` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): set timescale of all video tracks (from 0 to INT_MAX) (default 0)
    * `write_btrt` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :boolean): force or disable writing btrt (default auto)
    * `write_prft` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :int): Write producer reference time box with specified time source (from 0 to 2) (default 0) Reported constants: pts, wallclock.
    * `write_tmcd` (mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer, :boolean): force or disable writing tmcd (default auto)
    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
    * `flush_packets` (AVFormatContext, :int): enable flushing of the I/O context after each packet (from -1 to 1) (default -1)
    * `avoid_negative_ts` (AVFormatContext, :int): shift timestamps so they start at 0 (from -1 to 2) (default auto) Reported constants: auto, disabled, make_non_negative, make_zero.
  """
  @spec mov(Output.target(), [mov_option()]) :: Output.t()
  def mov(target, options) do
    build_output(target, "mov", options, @mov_schema)
  end

  @matroska_schema %{
    "allow_raw_vfw" => [%{type: :boolean, constants: []}],
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
    "avoid_negative_ts" => [
      %{type: :int, constants: ["auto", "disabled", "make_non_negative", "make_zero"]}
    ],
    "cluster_size_limit" => [%{type: :int, constants: []}],
    "cluster_time_limit" => [%{type: :int64, constants: []}],
    "cues_to_front" => [%{type: :boolean, constants: []}],
    "dash" => [%{type: :boolean, constants: []}],
    "dash_track_number" => [%{type: :int, constants: []}],
    "default_mode" => [%{type: :int, constants: ["infer", "infer_no_subs", "passthrough"]}],
    "fflags" => [
      %{
        type: :flags,
        constants: [
          "flush_packets",
          "ignidx",
          "genpts",
          "nofillin",
          "noparse",
          "igndts",
          "discardcorrupt",
          "sortdts",
          "fastseek",
          "nobuffer",
          "bitexact",
          "shortest",
          "autobsf"
        ]
      }
    ],
    "flipped_raw_rgb" => [%{type: :boolean, constants: []}],
    "flush_packets" => [%{type: :int, constants: []}],
    "live" => [%{type: :boolean, constants: []}],
    "max_delay" => [%{type: :int, constants: []}],
    "reserve_index_space" => [%{type: :int, constants: []}],
    "write_crc32" => [%{type: :boolean, constants: []}]
  }
  @type matroska_option ::
          {:allow_raw_vfw, boolean() | :auto | String.t()}
          | {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
          | {:avoid_negative_ts,
             integer() | String.t() | :auto | :disabled | :make_non_negative | :make_zero}
          | {:cluster_size_limit, integer() | String.t()}
          | {:cluster_time_limit, integer() | String.t()}
          | {:cues_to_front, boolean() | :auto | String.t()}
          | {:dash, boolean() | :auto | String.t()}
          | {:dash_track_number, integer() | String.t()}
          | {:default_mode, integer() | String.t() | :infer | :infer_no_subs | :passthrough}
          | {:fflags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :flush_packets
                 | :ignidx
                 | :genpts
                 | :nofillin
                 | :noparse
                 | :igndts
                 | :discardcorrupt
                 | :sortdts
                 | :fastseek
                 | :nobuffer
                 | :bitexact
                 | :shortest
                 | :autobsf
               ]
             | :flush_packets
             | :ignidx
             | :genpts
             | :nofillin
             | :noparse
             | :igndts
             | :discardcorrupt
             | :sortdts
             | :fastseek
             | :nobuffer
             | :bitexact
             | :shortest
             | :autobsf}
          | {:flipped_raw_rgb, boolean() | :auto | String.t()}
          | {:flush_packets, integer() | String.t()}
          | {:live, boolean() | :auto | String.t()}
          | {:max_delay, integer() | String.t()}
          | {:reserve_index_space, integer() | String.t()}
          | {:write_crc32, boolean() | :auto | String.t()}
          | {:raw, [Command.av_option()]}
          | {:video, Command.mapping() | [Command.mapping()]}
          | {:audio, Command.mapping() | [Command.mapping()]}
          | {:sources, [Command.mapping()]}
          | {:output_options, [Command.option()]}
  @doc """
  matroska: Matroska

  Builds an output declaration. Pass video/audio or ordered sources; raw CLI controls go in output_options.

    * Common extensions: mkv.
    * Mime type: video/x-matroska.
    * Default video codec: h264.
    * Default audio codec: vorbis.
    * Default subtitle codec: ass.

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `reserve_index_space` (matroska/webm muxer, :int): reserve a given amount of space (in bytes) at the beginning of the file for the index (cues) (from 0 to INT_MAX) (default 0)
    * `cues_to_front` (matroska/webm muxer, :boolean): move Cues (the index) to the front by shifting data if necessary (default false)
    * `cluster_size_limit` (matroska/webm muxer, :int): store at most the provided amount of bytes in a cluster (from -1 to INT_MAX) (default -1)
    * `cluster_time_limit` (matroska/webm muxer, :int64): store at most the provided number of milliseconds in a cluster (from -1 to I64_MAX) (default -1)
    * `dash` (matroska/webm muxer, :boolean): create a WebM file conforming to WebM DASH specification (default false)
    * `dash_track_number` (matroska/webm muxer, :int): track number for the DASH stream (from 1 to INT_MAX) (default 1)
    * `live` (matroska/webm muxer, :boolean): write files assuming it is a live stream (default false)
    * `allow_raw_vfw` (matroska/webm muxer, :boolean): allow raw VFW mode (default false)
    * `flipped_raw_rgb` (matroska/webm muxer, :boolean): store raw RGB bitmaps in VFW mode in bottom-up mode (default false)
    * `write_crc32` (matroska/webm muxer, :boolean): write a CRC32 element inside every Level 1 element (default true)
    * `default_mode` (matroska/webm muxer, :int): control how a track's FlagDefault is inferred (from 0 to 2) (default passthrough) Reported constants: infer, infer_no_subs, passthrough.
    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
    * `flush_packets` (AVFormatContext, :int): enable flushing of the I/O context after each packet (from -1 to 1) (default -1)
    * `avoid_negative_ts` (AVFormatContext, :int): shift timestamps so they start at 0 (from -1 to 2) (default auto) Reported constants: auto, disabled, make_non_negative, make_zero.
  """
  @spec matroska(Output.target(), [matroska_option()]) :: Output.t()
  def matroska(target, options) do
    build_output(target, "matroska", options, @matroska_schema)
  end

  @webm_schema %{
    "allow_raw_vfw" => [%{type: :boolean, constants: []}],
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
    "avoid_negative_ts" => [
      %{type: :int, constants: ["auto", "disabled", "make_non_negative", "make_zero"]}
    ],
    "cluster_size_limit" => [%{type: :int, constants: []}],
    "cluster_time_limit" => [%{type: :int64, constants: []}],
    "cues_to_front" => [%{type: :boolean, constants: []}],
    "dash" => [%{type: :boolean, constants: []}],
    "dash_track_number" => [%{type: :int, constants: []}],
    "default_mode" => [%{type: :int, constants: ["infer", "infer_no_subs", "passthrough"]}],
    "fflags" => [
      %{
        type: :flags,
        constants: [
          "flush_packets",
          "ignidx",
          "genpts",
          "nofillin",
          "noparse",
          "igndts",
          "discardcorrupt",
          "sortdts",
          "fastseek",
          "nobuffer",
          "bitexact",
          "shortest",
          "autobsf"
        ]
      }
    ],
    "flipped_raw_rgb" => [%{type: :boolean, constants: []}],
    "flush_packets" => [%{type: :int, constants: []}],
    "live" => [%{type: :boolean, constants: []}],
    "max_delay" => [%{type: :int, constants: []}],
    "reserve_index_space" => [%{type: :int, constants: []}],
    "write_crc32" => [%{type: :boolean, constants: []}]
  }
  @type webm_option ::
          {:allow_raw_vfw, boolean() | :auto | String.t()}
          | {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
          | {:avoid_negative_ts,
             integer() | String.t() | :auto | :disabled | :make_non_negative | :make_zero}
          | {:cluster_size_limit, integer() | String.t()}
          | {:cluster_time_limit, integer() | String.t()}
          | {:cues_to_front, boolean() | :auto | String.t()}
          | {:dash, boolean() | :auto | String.t()}
          | {:dash_track_number, integer() | String.t()}
          | {:default_mode, integer() | String.t() | :infer | :infer_no_subs | :passthrough}
          | {:fflags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :flush_packets
                 | :ignidx
                 | :genpts
                 | :nofillin
                 | :noparse
                 | :igndts
                 | :discardcorrupt
                 | :sortdts
                 | :fastseek
                 | :nobuffer
                 | :bitexact
                 | :shortest
                 | :autobsf
               ]
             | :flush_packets
             | :ignidx
             | :genpts
             | :nofillin
             | :noparse
             | :igndts
             | :discardcorrupt
             | :sortdts
             | :fastseek
             | :nobuffer
             | :bitexact
             | :shortest
             | :autobsf}
          | {:flipped_raw_rgb, boolean() | :auto | String.t()}
          | {:flush_packets, integer() | String.t()}
          | {:live, boolean() | :auto | String.t()}
          | {:max_delay, integer() | String.t()}
          | {:reserve_index_space, integer() | String.t()}
          | {:write_crc32, boolean() | :auto | String.t()}
          | {:raw, [Command.av_option()]}
          | {:video, Command.mapping() | [Command.mapping()]}
          | {:audio, Command.mapping() | [Command.mapping()]}
          | {:sources, [Command.mapping()]}
          | {:output_options, [Command.option()]}
  @doc """
  webm: WebM

  Builds an output declaration. Pass video/audio or ordered sources; raw CLI controls go in output_options.

    * Common extensions: webm.
    * Mime type: video/webm.
    * Default video codec: vp9.
    * Default audio codec: opus.
    * Default subtitle codec: webvtt.

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `reserve_index_space` (matroska/webm muxer, :int): reserve a given amount of space (in bytes) at the beginning of the file for the index (cues) (from 0 to INT_MAX) (default 0)
    * `cues_to_front` (matroska/webm muxer, :boolean): move Cues (the index) to the front by shifting data if necessary (default false)
    * `cluster_size_limit` (matroska/webm muxer, :int): store at most the provided amount of bytes in a cluster (from -1 to INT_MAX) (default -1)
    * `cluster_time_limit` (matroska/webm muxer, :int64): store at most the provided number of milliseconds in a cluster (from -1 to I64_MAX) (default -1)
    * `dash` (matroska/webm muxer, :boolean): create a WebM file conforming to WebM DASH specification (default false)
    * `dash_track_number` (matroska/webm muxer, :int): track number for the DASH stream (from 1 to INT_MAX) (default 1)
    * `live` (matroska/webm muxer, :boolean): write files assuming it is a live stream (default false)
    * `allow_raw_vfw` (matroska/webm muxer, :boolean): allow raw VFW mode (default false)
    * `flipped_raw_rgb` (matroska/webm muxer, :boolean): store raw RGB bitmaps in VFW mode in bottom-up mode (default false)
    * `write_crc32` (matroska/webm muxer, :boolean): write a CRC32 element inside every Level 1 element (default true)
    * `default_mode` (matroska/webm muxer, :int): control how a track's FlagDefault is inferred (from 0 to 2) (default passthrough) Reported constants: infer, infer_no_subs, passthrough.
    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
    * `flush_packets` (AVFormatContext, :int): enable flushing of the I/O context after each packet (from -1 to 1) (default -1)
    * `avoid_negative_ts` (AVFormatContext, :int): shift timestamps so they start at 0 (from -1 to 2) (default auto) Reported constants: auto, disabled, make_non_negative, make_zero.
  """
  @spec webm(Output.target(), [webm_option()]) :: Output.t()
  def webm(target, options) do
    build_output(target, "webm", options, @webm_schema)
  end

  @hls_schema %{
    "var_stream_map" => [%{type: :string, constants: []}],
    "hls_delete_threshold" => [%{type: :int, constants: []}],
    "flush_packets" => [%{type: :int, constants: []}],
    "hls_playlist_type" => [%{type: :int, constants: ["event", "vod"]}],
    "hls_time" => [%{type: :duration, constants: []}],
    "hls_base_url" => [%{type: :string, constants: []}],
    "hls_flags" => [
      %{
        type: :flags,
        constants: [
          "single_file",
          "temp_file",
          "delete_segments",
          "round_durations",
          "discont_start",
          "omit_endlist",
          "split_by_time",
          "append_list",
          "program_date_time",
          "second_level_segment_index",
          "second_level_segment_duration",
          "second_level_segment_size",
          "periodic_rekey",
          "independent_segments",
          "iframes_only"
        ]
      }
    ],
    "hls_enc_iv" => [%{type: :string, constants: []}],
    "ignore_io_errors" => [%{type: :boolean, constants: []}],
    "hls_init_time" => [%{type: :duration, constants: []}],
    "start_number" => [%{type: :int64, constants: []}],
    "hls_segment_type" => [%{type: :int, constants: ["mpegts", "fmp4"]}],
    "hls_vtt_options" => [%{type: :string, constants: []}],
    "hls_enc_key" => [%{type: :string, constants: []}],
    "hls_segment_size" => [%{type: :int, constants: []}],
    "hls_segment_filename" => [%{type: :string, constants: []}],
    "avoid_negative_ts" => [
      %{type: :int, constants: ["auto", "disabled", "make_non_negative", "make_zero"]}
    ],
    "hls_start_number_source" => [
      %{type: :int, constants: ["generic", "epoch", "epoch_us", "datetime"]}
    ],
    "hls_key_info_file" => [%{type: :string, constants: []}],
    "hls_allow_cache" => [%{type: :int, constants: []}],
    "master_pl_name" => [%{type: :string, constants: []}],
    "http_user_agent" => [%{type: :string, constants: []}],
    "hls_fmp4_init_filename" => [%{type: :string, constants: []}],
    "hls_fmp4_init_resend" => [%{type: :boolean, constants: []}],
    "method" => [%{type: :string, constants: []}],
    "max_delay" => [%{type: :int, constants: []}],
    "hls_segment_options" => [%{type: :dictionary, constants: []}],
    "strftime" => [%{type: :boolean, constants: []}],
    "fflags" => [
      %{
        type: :flags,
        constants: [
          "flush_packets",
          "ignidx",
          "genpts",
          "nofillin",
          "noparse",
          "igndts",
          "discardcorrupt",
          "sortdts",
          "fastseek",
          "nobuffer",
          "bitexact",
          "shortest",
          "autobsf"
        ]
      }
    ],
    "timeout" => [%{type: :duration, constants: []}],
    "headers" => [%{type: :string, constants: []}],
    "master_pl_publish_rate" => [%{type: :int, constants: []}],
    "hls_list_size" => [%{type: :int, constants: []}],
    "strftime_mkdir" => [%{type: :boolean, constants: []}],
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
    "hls_enc" => [%{type: :boolean, constants: []}],
    "cc_stream_map" => [%{type: :string, constants: []}],
    "hls_enc_key_url" => [%{type: :string, constants: []}],
    "hls_subtitle_path" => [%{type: :string, constants: []}],
    "http_persistent" => [%{type: :boolean, constants: []}]
  }
  @type hls_option ::
          {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
          | {:avoid_negative_ts,
             integer() | String.t() | :auto | :disabled | :make_non_negative | :make_zero}
          | {:cc_stream_map, String.t() | atom()}
          | {:fflags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :flush_packets
                 | :ignidx
                 | :genpts
                 | :nofillin
                 | :noparse
                 | :igndts
                 | :discardcorrupt
                 | :sortdts
                 | :fastseek
                 | :nobuffer
                 | :bitexact
                 | :shortest
                 | :autobsf
               ]
             | :flush_packets
             | :ignidx
             | :genpts
             | :nofillin
             | :noparse
             | :igndts
             | :discardcorrupt
             | :sortdts
             | :fastseek
             | :nobuffer
             | :bitexact
             | :shortest
             | :autobsf}
          | {:flush_packets, integer() | String.t()}
          | {:headers, String.t() | atom()}
          | {:hls_allow_cache, integer() | String.t()}
          | {:hls_base_url, String.t() | atom()}
          | {:hls_delete_threshold, integer() | String.t()}
          | {:hls_enc, boolean() | :auto | String.t()}
          | {:hls_enc_iv, String.t() | atom()}
          | {:hls_enc_key, String.t() | atom()}
          | {:hls_enc_key_url, String.t() | atom()}
          | {:hls_flags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :single_file
                 | :temp_file
                 | :delete_segments
                 | :round_durations
                 | :discont_start
                 | :omit_endlist
                 | :split_by_time
                 | :append_list
                 | :program_date_time
                 | :second_level_segment_index
                 | :second_level_segment_duration
                 | :second_level_segment_size
                 | :periodic_rekey
                 | :independent_segments
                 | :iframes_only
               ]
             | :single_file
             | :temp_file
             | :delete_segments
             | :round_durations
             | :discont_start
             | :omit_endlist
             | :split_by_time
             | :append_list
             | :program_date_time
             | :second_level_segment_index
             | :second_level_segment_duration
             | :second_level_segment_size
             | :periodic_rekey
             | :independent_segments
             | :iframes_only}
          | {:hls_fmp4_init_filename, String.t() | atom()}
          | {:hls_fmp4_init_resend, boolean() | :auto | String.t()}
          | {:hls_init_time, number() | String.t()}
          | {:hls_key_info_file, String.t() | atom()}
          | {:hls_list_size, integer() | String.t()}
          | {:hls_playlist_type, integer() | String.t() | :event | :vod}
          | {:hls_segment_filename, String.t() | atom()}
          | {:hls_segment_options, String.t() | atom()}
          | {:hls_segment_size, integer() | String.t()}
          | {:hls_segment_type, integer() | String.t() | :mpegts | :fmp4}
          | {:hls_start_number_source,
             integer() | String.t() | :generic | :epoch | :epoch_us | :datetime}
          | {:hls_subtitle_path, String.t() | atom()}
          | {:hls_time, number() | String.t()}
          | {:hls_vtt_options, String.t() | atom()}
          | {:http_persistent, boolean() | :auto | String.t()}
          | {:http_user_agent, String.t() | atom()}
          | {:ignore_io_errors, boolean() | :auto | String.t()}
          | {:master_pl_name, String.t() | atom()}
          | {:master_pl_publish_rate, integer() | String.t()}
          | {:max_delay, integer() | String.t()}
          | {:method, String.t() | atom()}
          | {:start_number, integer() | String.t()}
          | {:strftime, boolean() | :auto | String.t()}
          | {:strftime_mkdir, boolean() | :auto | String.t()}
          | {:timeout, number() | String.t()}
          | {:var_stream_map, String.t() | atom()}
          | {:raw, [Command.av_option()]}
          | {:video, Command.mapping() | [Command.mapping()]}
          | {:audio, Command.mapping() | [Command.mapping()]}
          | {:sources, [Command.mapping()]}
          | {:output_options, [Command.option()]}
  @doc """
  hls: Apple HTTP Live Streaming

  Builds an output declaration. Pass video/audio or ordered sources; raw CLI controls go in output_options.

    * Common extensions: m3u8.
    * Default video codec: h264.
    * Default audio codec: aac.
    * Default subtitle codec: webvtt.

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `start_number` (hls muxer, :int64): set first number in the sequence (from 0 to I64_MAX) (default 0)
    * `hls_time` (hls muxer, :duration): set segment length (default 2)
    * `hls_init_time` (hls muxer, :duration): set segment length at init list (default 0)
    * `hls_list_size` (hls muxer, :int): set maximum number of playlist entries (from 0 to INT_MAX) (default 5)
    * `hls_delete_threshold` (hls muxer, :int): set number of unreferenced segments to keep before deleting (from 1 to INT_MAX) (default 1)
    * `hls_vtt_options` (hls muxer, :string): set hls vtt list of options for the container format used for hls
    * `hls_allow_cache` (hls muxer, :int): explicitly set whether the client MAY (1) or MUST NOT (0) cache media segments (from INT_MIN to INT_MAX) (default -1)
    * `hls_base_url` (hls muxer, :string): url to prepend to each playlist entry
    * `hls_segment_filename` (hls muxer, :string): filename template for segment files
    * `hls_segment_options` (hls muxer, :dictionary): set segments files format options of hls
    * `hls_segment_size` (hls muxer, :int): maximum size per segment file, (in bytes) (from 0 to INT_MAX) (default 0)
    * `hls_key_info_file` (hls muxer, :string): file with key URI and key file path
    * `hls_enc` (hls muxer, :boolean): enable AES128 encryption support (default false)
    * `hls_enc_key` (hls muxer, :string): hex-coded 16 byte key to encrypt the segments
    * `hls_enc_key_url` (hls muxer, :string): url to access the key to decrypt the segments
    * `hls_enc_iv` (hls muxer, :string): hex-coded 16 byte initialization vector
    * `hls_subtitle_path` (hls muxer, :string): set path of hls subtitles
    * `hls_segment_type` (hls muxer, :int): set hls segment files type (from 0 to 1) (default mpegts) Reported constants: mpegts, fmp4.
    * `hls_fmp4_init_filename` (hls muxer, :string): set fragment mp4 file init filename (default \"init.mp4\")
    * `hls_fmp4_init_resend` (hls muxer, :boolean): resend fragment mp4 init file after refresh m3u8 every time (default false)
    * `hls_flags` (hls muxer, :flags): set flags affecting HLS playlist and media file generation (default 0) Reported constants: single_file, temp_file, delete_segments, round_durations, discont_start, omit_endlist, split_by_time, append_list, program_date_time, second_level_segment_index, second_level_segment_duration, second_level_segment_size, periodic_rekey, independent_segments, iframes_only.
    * `strftime` (hls muxer, :boolean): set filename expansion with strftime at segment creation (default false)
    * `strftime_mkdir` (hls muxer, :boolean): create last directory component in strftime-generated filename (default false)
    * `hls_playlist_type` (hls muxer, :int): set the HLS playlist type (from 0 to 2) (default 0) Reported constants: event, vod.
    * `method` (hls muxer, :string): set the HTTP method(default: PUT)
    * `hls_start_number_source` (hls muxer, :int): set source of first number in sequence (from 0 to 3) (default generic) Reported constants: generic, epoch, epoch_us, datetime.
    * `http_user_agent` (hls muxer, :string): override User-Agent field in HTTP header
    * `var_stream_map` (hls muxer, :string): Variant stream map string
    * `cc_stream_map` (hls muxer, :string): Closed captions stream map string
    * `master_pl_name` (hls muxer, :string): Create HLS master playlist with this name
    * `master_pl_publish_rate` (hls muxer, :int): Publish master play list every after this many segment intervals (from 0 to UINT32_MAX) (default 0)
    * `http_persistent` (hls muxer, :boolean): Use persistent HTTP connections (default false)
    * `timeout` (hls muxer, :duration): set timeout for socket I/O operations (default -0.000001)
    * `ignore_io_errors` (hls muxer, :boolean): Ignore IO errors for stable long-duration runs with network output (default false)
    * `headers` (hls muxer, :string): set custom HTTP headers, can override built in default headers
    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
    * `flush_packets` (AVFormatContext, :int): enable flushing of the I/O context after each packet (from -1 to 1) (default -1)
    * `avoid_negative_ts` (AVFormatContext, :int): shift timestamps so they start at 0 (from -1 to 2) (default auto) Reported constants: auto, disabled, make_non_negative, make_zero.
  """
  @spec hls(Output.target(), [hls_option()]) :: Output.t()
  def hls(target, options) do
    build_output(target, "hls", options, @hls_schema)
  end

  @mpegts_schema %{
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
    "avoid_negative_ts" => [
      %{type: :int, constants: ["auto", "disabled", "make_non_negative", "make_zero"]}
    ],
    "fflags" => [
      %{
        type: :flags,
        constants: [
          "flush_packets",
          "ignidx",
          "genpts",
          "nofillin",
          "noparse",
          "igndts",
          "discardcorrupt",
          "sortdts",
          "fastseek",
          "nobuffer",
          "bitexact",
          "shortest",
          "autobsf"
        ]
      }
    ],
    "flush_packets" => [%{type: :int, constants: []}],
    "max_delay" => [%{type: :int, constants: []}],
    "mpegts_copyts" => [%{type: :boolean, constants: []}],
    "mpegts_flags" => [
      %{
        type: :flags,
        constants: [
          "resend_headers",
          "latm",
          "pat_pmt_at_frames",
          "system_b",
          "initial_discontinuity",
          "nit",
          "omit_rai"
        ]
      }
    ],
    "mpegts_m2ts_mode" => [%{type: :boolean, constants: []}],
    "mpegts_original_network_id" => [%{type: :int, constants: []}],
    "mpegts_pmt_start_pid" => [%{type: :int, constants: []}],
    "mpegts_service_id" => [%{type: :int, constants: []}],
    "mpegts_service_type" => [
      %{
        type: :int,
        constants: [
          "digital_tv",
          "digital_radio",
          "teletext",
          "advanced_codec_digital_radio",
          "mpeg2_digital_hdtv",
          "advanced_codec_digital_sdtv",
          "advanced_codec_digital_hdtv",
          "hevc_digital_hdtv"
        ]
      }
    ],
    "mpegts_start_pid" => [%{type: :int, constants: []}],
    "mpegts_transport_stream_id" => [%{type: :int, constants: []}],
    "muxrate" => [%{type: :int, constants: []}],
    "nit_period" => [%{type: :duration, constants: []}],
    "omit_video_pes_length" => [%{type: :boolean, constants: []}],
    "pat_period" => [%{type: :duration, constants: []}],
    "pcr_period" => [%{type: :int, constants: []}],
    "pes_payload_size" => [%{type: :int, constants: []}],
    "sdt_period" => [%{type: :duration, constants: []}],
    "tables_version" => [%{type: :int, constants: []}]
  }
  @type mpegts_option ::
          {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
          | {:avoid_negative_ts,
             integer() | String.t() | :auto | :disabled | :make_non_negative | :make_zero}
          | {:fflags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :flush_packets
                 | :ignidx
                 | :genpts
                 | :nofillin
                 | :noparse
                 | :igndts
                 | :discardcorrupt
                 | :sortdts
                 | :fastseek
                 | :nobuffer
                 | :bitexact
                 | :shortest
                 | :autobsf
               ]
             | :flush_packets
             | :ignidx
             | :genpts
             | :nofillin
             | :noparse
             | :igndts
             | :discardcorrupt
             | :sortdts
             | :fastseek
             | :nobuffer
             | :bitexact
             | :shortest
             | :autobsf}
          | {:flush_packets, integer() | String.t()}
          | {:max_delay, integer() | String.t()}
          | {:mpegts_copyts, boolean() | :auto | String.t()}
          | {:mpegts_flags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :resend_headers
                 | :latm
                 | :pat_pmt_at_frames
                 | :system_b
                 | :initial_discontinuity
                 | :nit
                 | :omit_rai
               ]
             | :resend_headers
             | :latm
             | :pat_pmt_at_frames
             | :system_b
             | :initial_discontinuity
             | :nit
             | :omit_rai}
          | {:mpegts_m2ts_mode, boolean() | :auto | String.t()}
          | {:mpegts_original_network_id, integer() | String.t()}
          | {:mpegts_pmt_start_pid, integer() | String.t()}
          | {:mpegts_service_id, integer() | String.t()}
          | {:mpegts_service_type,
             integer()
             | String.t()
             | :digital_tv
             | :digital_radio
             | :teletext
             | :advanced_codec_digital_radio
             | :mpeg2_digital_hdtv
             | :advanced_codec_digital_sdtv
             | :advanced_codec_digital_hdtv
             | :hevc_digital_hdtv}
          | {:mpegts_start_pid, integer() | String.t()}
          | {:mpegts_transport_stream_id, integer() | String.t()}
          | {:muxrate, integer() | String.t()}
          | {:nit_period, number() | String.t()}
          | {:omit_video_pes_length, boolean() | :auto | String.t()}
          | {:pat_period, number() | String.t()}
          | {:pcr_period, integer() | String.t()}
          | {:pes_payload_size, integer() | String.t()}
          | {:sdt_period, number() | String.t()}
          | {:tables_version, integer() | String.t()}
          | {:raw, [Command.av_option()]}
          | {:video, Command.mapping() | [Command.mapping()]}
          | {:audio, Command.mapping() | [Command.mapping()]}
          | {:sources, [Command.mapping()]}
          | {:output_options, [Command.option()]}
  @doc """
  mpegts: MPEG-TS (MPEG-2 Transport Stream)

  Builds an output declaration. Pass video/audio or ordered sources; raw CLI controls go in output_options.

    * Common extensions: ts,m2t,m2ts,mts.
    * Mime type: video/MP2T.
    * Default video codec: mpeg2video.
    * Default audio codec: mp2.

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `mpegts_transport_stream_id` (MPEGTS muxer, :int): Set transport_stream_id field. (from 1 to 65535) (default 1)
    * `mpegts_original_network_id` (MPEGTS muxer, :int): Set original_network_id field. (from 1 to 65535) (default 65281)
    * `mpegts_service_id` (MPEGTS muxer, :int): Set service_id field. (from 1 to 65535) (default 1)
    * `mpegts_service_type` (MPEGTS muxer, :int): Set service_type field. (from 1 to 255) (default digital_tv) Reported constants: digital_tv, digital_radio, teletext, advanced_codec_digital_radio, mpeg2_digital_hdtv, advanced_codec_digital_sdtv, advanced_codec_digital_hdtv, hevc_digital_hdtv.
    * `mpegts_pmt_start_pid` (MPEGTS muxer, :int): Set the first pid of the PMT. (from 32 to 8186) (default 4096)
    * `mpegts_start_pid` (MPEGTS muxer, :int): Set the first pid. (from 32 to 8186) (default 256)
    * `mpegts_m2ts_mode` (MPEGTS muxer, :boolean): Enable m2ts mode. (default auto)
    * `muxrate` (MPEGTS muxer, :int): (from 0 to INT_MAX) (default 1)
    * `pes_payload_size` (MPEGTS muxer, :int): Minimum PES packet payload in bytes (from 0 to INT_MAX) (default 2930)
    * `mpegts_flags` (MPEGTS muxer, :flags): MPEG-TS muxing flags (default 0) Reported constants: resend_headers, latm, pat_pmt_at_frames, system_b, initial_discontinuity, nit, omit_rai.
    * `mpegts_copyts` (MPEGTS muxer, :boolean): don't offset dts/pts (default auto)
    * `tables_version` (MPEGTS muxer, :int): set PAT, PMT, SDT and NIT version (from 0 to 31) (default 0)
    * `omit_video_pes_length` (MPEGTS muxer, :boolean): Omit the PES packet length for video packets (default true)
    * `pcr_period` (MPEGTS muxer, :int): PCR retransmission time in milliseconds (from -1 to INT_MAX) (default -1)
    * `pat_period` (MPEGTS muxer, :duration): PAT/PMT retransmission time limit in seconds (default 0.1)
    * `sdt_period` (MPEGTS muxer, :duration): SDT retransmission time limit in seconds (default 0.5)
    * `nit_period` (MPEGTS muxer, :duration): NIT retransmission time limit in seconds (default 0.5)
    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
    * `flush_packets` (AVFormatContext, :int): enable flushing of the I/O context after each packet (from -1 to 1) (default -1)
    * `avoid_negative_ts` (AVFormatContext, :int): shift timestamps so they start at 0 (from -1 to 2) (default auto) Reported constants: auto, disabled, make_non_negative, make_zero.
  """
  @spec mpegts(Output.target(), [mpegts_option()]) :: Output.t()
  def mpegts(target, options) do
    build_output(target, "mpegts", options, @mpegts_schema)
  end

  @segment_schema %{
    "segment_clocktime_offset" => [%{type: :duration, constants: []}],
    "segment_wrap" => [%{type: :int, constants: []}],
    "flush_packets" => [%{type: :int, constants: []}],
    "segment_format" => [%{type: :string, constants: []}],
    "initial_offset" => [%{type: :duration, constants: []}],
    "segment_wrap_number" => [%{type: :int, constants: []}],
    "increment_tc" => [%{type: :boolean, constants: []}],
    "segment_times" => [%{type: :string, constants: []}],
    "avoid_negative_ts" => [
      %{type: :int, constants: ["auto", "disabled", "make_non_negative", "make_zero"]}
    ],
    "segment_list_flags" => [%{type: :flags, constants: ["cache", "live"]}],
    "segment_format_options" => [%{type: :dictionary, constants: []}],
    "segment_atclocktime" => [%{type: :boolean, constants: []}],
    "min_seg_duration" => [%{type: :duration, constants: []}],
    "max_delay" => [%{type: :int, constants: []}],
    "segment_list" => [%{type: :string, constants: []}],
    "strftime" => [%{type: :boolean, constants: []}],
    "fflags" => [
      %{
        type: :flags,
        constants: [
          "flush_packets",
          "ignidx",
          "genpts",
          "nofillin",
          "noparse",
          "igndts",
          "discardcorrupt",
          "sortdts",
          "fastseek",
          "nobuffer",
          "bitexact",
          "shortest",
          "autobsf"
        ]
      }
    ],
    "segment_start_number" => [%{type: :int, constants: []}],
    "individual_header_trailer" => [%{type: :boolean, constants: []}],
    "segment_list_entry_prefix" => [%{type: :string, constants: []}],
    "segment_time_delta" => [%{type: :duration, constants: []}],
    "segment_clocktime_wrap_duration" => [%{type: :duration, constants: []}],
    "segment_list_size" => [%{type: :int, constants: []}],
    "reset_timestamps" => [%{type: :boolean, constants: []}],
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
    "segment_list_type" => [
      %{type: :int, constants: ["flat", "csv", "ext", "ffconcat", "m3u8", "hls"]}
    ],
    "segment_time" => [%{type: :duration, constants: []}],
    "segment_header_filename" => [%{type: :string, constants: []}],
    "write_header_trailer" => [%{type: :boolean, constants: []}],
    "write_empty_segments" => [%{type: :boolean, constants: []}],
    "segment_frames" => [%{type: :string, constants: []}],
    "break_non_keyframes" => [%{type: :boolean, constants: []}],
    "reference_stream" => [%{type: :string, constants: []}]
  }
  @type segment_option ::
          {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
          | {:avoid_negative_ts,
             integer() | String.t() | :auto | :disabled | :make_non_negative | :make_zero}
          | {:break_non_keyframes, boolean() | :auto | String.t()}
          | {:fflags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :flush_packets
                 | :ignidx
                 | :genpts
                 | :nofillin
                 | :noparse
                 | :igndts
                 | :discardcorrupt
                 | :sortdts
                 | :fastseek
                 | :nobuffer
                 | :bitexact
                 | :shortest
                 | :autobsf
               ]
             | :flush_packets
             | :ignidx
             | :genpts
             | :nofillin
             | :noparse
             | :igndts
             | :discardcorrupt
             | :sortdts
             | :fastseek
             | :nobuffer
             | :bitexact
             | :shortest
             | :autobsf}
          | {:flush_packets, integer() | String.t()}
          | {:increment_tc, boolean() | :auto | String.t()}
          | {:individual_header_trailer, boolean() | :auto | String.t()}
          | {:initial_offset, number() | String.t()}
          | {:max_delay, integer() | String.t()}
          | {:min_seg_duration, number() | String.t()}
          | {:reference_stream, String.t() | atom()}
          | {:reset_timestamps, boolean() | :auto | String.t()}
          | {:segment_atclocktime, boolean() | :auto | String.t()}
          | {:segment_clocktime_offset, number() | String.t()}
          | {:segment_clocktime_wrap_duration, number() | String.t()}
          | {:segment_format, String.t() | atom()}
          | {:segment_format_options, String.t() | atom()}
          | {:segment_frames, String.t() | atom()}
          | {:segment_header_filename, String.t() | atom()}
          | {:segment_list, String.t() | atom()}
          | {:segment_list_entry_prefix, String.t() | atom()}
          | {:segment_list_flags,
             integer() | String.t() | [String.t() | :cache | :live] | :cache | :live}
          | {:segment_list_size, integer() | String.t()}
          | {:segment_list_type,
             integer() | String.t() | :flat | :csv | :ext | :ffconcat | :m3u8 | :hls}
          | {:segment_start_number, integer() | String.t()}
          | {:segment_time, number() | String.t()}
          | {:segment_time_delta, number() | String.t()}
          | {:segment_times, String.t() | atom()}
          | {:segment_wrap, integer() | String.t()}
          | {:segment_wrap_number, integer() | String.t()}
          | {:strftime, boolean() | :auto | String.t()}
          | {:write_empty_segments, boolean() | :auto | String.t()}
          | {:write_header_trailer, boolean() | :auto | String.t()}
          | {:raw, [Command.av_option()]}
          | {:video, Command.mapping() | [Command.mapping()]}
          | {:audio, Command.mapping() | [Command.mapping()]}
          | {:sources, [Command.mapping()]}
          | {:output_options, [Command.option()]}
  @doc """
  segment: segment

  Builds an output declaration. Pass video/audio or ordered sources; raw CLI controls go in output_options.



  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `reference_stream` ((stream) segment muxer, :string): set reference stream (default \"auto\")
    * `segment_format` ((stream) segment muxer, :string): set container format used for the segments
    * `segment_format_options` ((stream) segment muxer, :dictionary): set list of options for the container format used for the segments
    * `segment_list` ((stream) segment muxer, :string): set the segment list filename
    * `segment_header_filename` ((stream) segment muxer, :string): write a single file containing the header
    * `segment_list_flags` ((stream) segment muxer, :flags): set flags affecting segment list generation (default cache) Reported constants: cache, live.
    * `segment_list_size` ((stream) segment muxer, :int): set the maximum number of playlist entries (from 0 to INT_MAX) (default 0)
    * `segment_list_type` ((stream) segment muxer, :int): set the segment list type (from -1 to 4) (default -1) Reported constants: flat, csv, ext, ffconcat, m3u8, hls.
    * `segment_atclocktime` ((stream) segment muxer, :boolean): set segment to be cut at clocktime (default false)
    * `segment_clocktime_offset` ((stream) segment muxer, :duration): set segment clocktime offset (default 0)
    * `segment_clocktime_wrap_duration` ((stream) segment muxer, :duration): set segment clocktime wrapping duration (default INT64_MAX)
    * `segment_time` ((stream) segment muxer, :duration): set segment duration (default 2)
    * `segment_time_delta` ((stream) segment muxer, :duration): set approximation value used for the segment times (default 0)
    * `min_seg_duration` ((stream) segment muxer, :duration): set minimum segment duration (default 0)
    * `segment_times` ((stream) segment muxer, :string): set segment split time points
    * `segment_frames` ((stream) segment muxer, :string): set segment split frame numbers
    * `segment_wrap` ((stream) segment muxer, :int): set number after which the index wraps (from 0 to INT_MAX) (default 0)
    * `segment_list_entry_prefix` ((stream) segment muxer, :string): set base url prefix for segments
    * `segment_start_number` ((stream) segment muxer, :int): set the sequence number of the first segment (from 0 to INT_MAX) (default 0)
    * `segment_wrap_number` ((stream) segment muxer, :int): set the number of wrap before the first segment (from 0 to INT_MAX) (default 0)
    * `strftime` ((stream) segment muxer, :boolean): set filename expansion with strftime at segment creation (default false)
    * `increment_tc` ((stream) segment muxer, :boolean): increment timecode between each segment (default false)
    * `break_non_keyframes` ((stream) segment muxer, :boolean): allow breaking segments on non-keyframes (default false)
    * `individual_header_trailer` ((stream) segment muxer, :boolean): write header/trailer to each segment (default true)
    * `write_header_trailer` ((stream) segment muxer, :boolean): write a header to the first segment and a trailer to the last one (default true)
    * `reset_timestamps` ((stream) segment muxer, :boolean): reset timestamps at the beginning of each segment (default false)
    * `initial_offset` ((stream) segment muxer, :duration): set initial timestamp offset (default 0)
    * `write_empty_segments` ((stream) segment muxer, :boolean): allow writing empty 'filler' segments (default false)
    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
    * `flush_packets` (AVFormatContext, :int): enable flushing of the I/O context after each packet (from -1 to 1) (default -1)
    * `avoid_negative_ts` (AVFormatContext, :int): shift timestamps so they start at 0 (from -1 to 2) (default auto) Reported constants: auto, disabled, make_non_negative, make_zero.
  """
  @spec segment(Output.target(), [segment_option()]) :: Output.t()
  def segment(target, options) do
    build_output(target, "segment", options, @segment_schema)
  end

  @tee_schema %{
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
    "avoid_negative_ts" => [
      %{type: :int, constants: ["auto", "disabled", "make_non_negative", "make_zero"]}
    ],
    "fflags" => [
      %{
        type: :flags,
        constants: [
          "flush_packets",
          "ignidx",
          "genpts",
          "nofillin",
          "noparse",
          "igndts",
          "discardcorrupt",
          "sortdts",
          "fastseek",
          "nobuffer",
          "bitexact",
          "shortest",
          "autobsf"
        ]
      }
    ],
    "fifo_options" => [%{type: :dictionary, constants: []}],
    "flush_packets" => [%{type: :int, constants: []}],
    "max_delay" => [%{type: :int, constants: []}],
    "use_fifo" => [%{type: :boolean, constants: []}]
  }
  @type tee_option ::
          {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
          | {:avoid_negative_ts,
             integer() | String.t() | :auto | :disabled | :make_non_negative | :make_zero}
          | {:fflags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :flush_packets
                 | :ignidx
                 | :genpts
                 | :nofillin
                 | :noparse
                 | :igndts
                 | :discardcorrupt
                 | :sortdts
                 | :fastseek
                 | :nobuffer
                 | :bitexact
                 | :shortest
                 | :autobsf
               ]
             | :flush_packets
             | :ignidx
             | :genpts
             | :nofillin
             | :noparse
             | :igndts
             | :discardcorrupt
             | :sortdts
             | :fastseek
             | :nobuffer
             | :bitexact
             | :shortest
             | :autobsf}
          | {:fifo_options, String.t() | atom()}
          | {:flush_packets, integer() | String.t()}
          | {:max_delay, integer() | String.t()}
          | {:use_fifo, boolean() | :auto | String.t()}
          | {:raw, [Command.av_option()]}
          | {:video, Command.mapping() | [Command.mapping()]}
          | {:audio, Command.mapping() | [Command.mapping()]}
          | {:sources, [Command.mapping()]}
          | {:output_options, [Command.option()]}
  @doc """
  tee: Multiple muxer tee

  Builds an output declaration. Pass video/audio or ordered sources; raw CLI controls go in output_options.



  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `use_fifo` (Tee muxer, :boolean): Use fifo pseudo-muxer to separate actual muxers from encoder (default false)
    * `fifo_options` (Tee muxer, :dictionary): fifo pseudo-muxer options
    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
    * `flush_packets` (AVFormatContext, :int): enable flushing of the I/O context after each packet (from -1 to 1) (default -1)
    * `avoid_negative_ts` (AVFormatContext, :int): shift timestamps so they start at 0 (from -1 to 2) (default auto) Reported constants: auto, disabled, make_non_negative, make_zero.
  """
  @spec tee(Output.target(), [tee_option()]) :: Output.t()
  def tee(target, options) do
    build_output(target, "tee", options, @tee_schema)
  end

  @null_schema %{
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
    "avoid_negative_ts" => [
      %{type: :int, constants: ["auto", "disabled", "make_non_negative", "make_zero"]}
    ],
    "fflags" => [
      %{
        type: :flags,
        constants: [
          "flush_packets",
          "ignidx",
          "genpts",
          "nofillin",
          "noparse",
          "igndts",
          "discardcorrupt",
          "sortdts",
          "fastseek",
          "nobuffer",
          "bitexact",
          "shortest",
          "autobsf"
        ]
      }
    ],
    "flush_packets" => [%{type: :int, constants: []}],
    "max_delay" => [%{type: :int, constants: []}]
  }
  @type null_option ::
          {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
          | {:avoid_negative_ts,
             integer() | String.t() | :auto | :disabled | :make_non_negative | :make_zero}
          | {:fflags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :flush_packets
                 | :ignidx
                 | :genpts
                 | :nofillin
                 | :noparse
                 | :igndts
                 | :discardcorrupt
                 | :sortdts
                 | :fastseek
                 | :nobuffer
                 | :bitexact
                 | :shortest
                 | :autobsf
               ]
             | :flush_packets
             | :ignidx
             | :genpts
             | :nofillin
             | :noparse
             | :igndts
             | :discardcorrupt
             | :sortdts
             | :fastseek
             | :nobuffer
             | :bitexact
             | :shortest
             | :autobsf}
          | {:flush_packets, integer() | String.t()}
          | {:max_delay, integer() | String.t()}
          | {:raw, [Command.av_option()]}
          | {:video, Command.mapping() | [Command.mapping()]}
          | {:audio, Command.mapping() | [Command.mapping()]}
          | {:sources, [Command.mapping()]}
          | {:output_options, [Command.option()]}
  @doc """
  null: raw null video

  Builds an output declaration. Pass video/audio or ordered sources; raw CLI controls go in output_options.

    * Default video codec: wrapped_avframe.
    * Default audio codec: pcm_s16le.

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
    * `flush_packets` (AVFormatContext, :int): enable flushing of the I/O context after each packet (from -1 to 1) (default -1)
    * `avoid_negative_ts` (AVFormatContext, :int): shift timestamps so they start at 0 (from -1 to 2) (default auto) Reported constants: auto, disabled, make_non_negative, make_zero.
  """
  @spec null(Output.target(), [null_option()]) :: Output.t()
  def null(target, options) do
    build_output(target, "null", options, @null_schema)
  end

  @image2_schema %{
    "atomic_writing" => [%{type: :boolean, constants: []}],
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
    "avoid_negative_ts" => [
      %{type: :int, constants: ["auto", "disabled", "make_non_negative", "make_zero"]}
    ],
    "fflags" => [
      %{
        type: :flags,
        constants: [
          "flush_packets",
          "ignidx",
          "genpts",
          "nofillin",
          "noparse",
          "igndts",
          "discardcorrupt",
          "sortdts",
          "fastseek",
          "nobuffer",
          "bitexact",
          "shortest",
          "autobsf"
        ]
      }
    ],
    "flush_packets" => [%{type: :int, constants: []}],
    "frame_pts" => [%{type: :boolean, constants: []}],
    "max_delay" => [%{type: :int, constants: []}],
    "protocol_opts" => [%{type: :dictionary, constants: []}],
    "start_number" => [%{type: :int, constants: []}],
    "strftime" => [%{type: :boolean, constants: []}],
    "update" => [%{type: :boolean, constants: []}]
  }
  @type image2_option ::
          {:atomic_writing, boolean() | :auto | String.t()}
          | {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
          | {:avoid_negative_ts,
             integer() | String.t() | :auto | :disabled | :make_non_negative | :make_zero}
          | {:fflags,
             integer()
             | String.t()
             | [
                 String.t()
                 | :flush_packets
                 | :ignidx
                 | :genpts
                 | :nofillin
                 | :noparse
                 | :igndts
                 | :discardcorrupt
                 | :sortdts
                 | :fastseek
                 | :nobuffer
                 | :bitexact
                 | :shortest
                 | :autobsf
               ]
             | :flush_packets
             | :ignidx
             | :genpts
             | :nofillin
             | :noparse
             | :igndts
             | :discardcorrupt
             | :sortdts
             | :fastseek
             | :nobuffer
             | :bitexact
             | :shortest
             | :autobsf}
          | {:flush_packets, integer() | String.t()}
          | {:frame_pts, boolean() | :auto | String.t()}
          | {:max_delay, integer() | String.t()}
          | {:protocol_opts, String.t() | atom()}
          | {:start_number, integer() | String.t()}
          | {:strftime, boolean() | :auto | String.t()}
          | {:update, boolean() | :auto | String.t()}
          | {:raw, [Command.av_option()]}
          | {:video, Command.mapping() | [Command.mapping()]}
          | {:audio, Command.mapping() | [Command.mapping()]}
          | {:sources, [Command.mapping()]}
          | {:output_options, [Command.option()]}
  @doc """
  image2: image2 sequence

  Builds an output declaration. Pass video/audio or ordered sources; raw CLI controls go in output_options.

    * Common extensions: bmp,dpx,exr,jls,jpeg,jpg,jxl,ljpg,pam,pbm,pcx,pfm,pgm,pgmyuv,phm,png,ppm,sgi,tga,tif,tiff,jp2,j2c,j2k,xwd,sun,ras,rs,im1,im8,im24,sunras,vbn,xbm,xface,pix,y,avif,qoi,hdr,wbmp.
    * Default video codec: mjpeg.

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `update` (image2 muxer, :boolean): continuously overwrite one file (default false)
    * `start_number` (image2 muxer, :int): set first number in the sequence (from 0 to INT_MAX) (default 1)
    * `strftime` (image2 muxer, :boolean): use strftime for filename (default false)
    * `frame_pts` (image2 muxer, :boolean): use current frame pts for filename (default false)
    * `atomic_writing` (image2 muxer, :boolean): write files atomically (using temporary files and renames) (default false)
    * `protocol_opts` (image2 muxer, :dictionary): specify protocol options for the opened files
    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
    * `flush_packets` (AVFormatContext, :int): enable flushing of the I/O context after each packet (from -1 to 1) (default -1)
    * `avoid_negative_ts` (AVFormatContext, :int): shift timestamps so they start at 0 (from -1 to 2) (default auto) Reported constants: auto, disabled, make_non_negative, make_zero.
  """
  @spec image2(Output.target(), [image2_option()]) :: Output.t()
  def image2(target, options) do
    build_output(target, "image2", options, @image2_schema)
  end

  # END GENERATED HELPERS
end
