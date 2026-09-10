defmodule FFix.Demuxer do
  @moduledoc """
  Format-specific input shortcuts and low-level demuxer configuration.

  Named helpers return `FFix.Command.Input` declarations and force a format.
  Top-level options configure demuxer AVOptions; put raw input CLI controls in
  `input_options:`. Retain `FFix.input/2` for automatic format detection.

      FFix.Demuxer.rawvideo("frames.rgb",
        video_size: "1920x1080",
        pixel_format: "rgb24",
        framerate: 30
      )

  Helpers and option schemas come from recorded FFmpeg metadata. Aliases such as
  MOV/MP4 refer to the input registration, not the correspondingly named muxers.
  Some input formats are device backends; a helper does not establish hardware
  availability. No discovery or default-option population occurs on construction.

  Strings remain open FFmpeg values, and flag lists are normalized. Use
  `raw: [{"new_option", "value"}]` to bypass metadata checks for selected options,
  or `named/3` for a dynamic format without a recorded schema. `new/2` builds an
  unbound configuration for `FFix.Command.Input.demuxer`.
  """

  alias FFix.Command
  alias FFix.Command.Input
  alias FFix.Options

  @type t :: %__MODULE__{name: String.t() | nil, options: [Command.av_option()]}
  defstruct [:name, options: []]

  @doc "Builds an unbound demuxer configuration without a metadata schema."
  @spec new(String.t() | nil, [Command.av_option()]) :: t()
  def new(name, options \\ []) do
    Command.validate_component!(%__MODULE__{name: name, options: options})
  end

  @doc "Builds an input for a dynamic demuxer name; extra CLI controls go in input_options."
  @spec named(Input.source(), String.t(), list()) :: Input.t()
  def named(source, name, options \\ []), do: build_input(source, name, options, nil)

  defp build_input(source, name, options, schema) do
    {bindings, options} = Options.split!(options, [:input_options])
    input_options = Keyword.get(bindings, :input_options, [])
    {_special, input_options} = Options.split!(input_options, [])
    demuxer_options = Options.normalize!(options, schema, "#{name} demuxer")
    input = Command.input(source)
    %{input | demuxer: new(name, demuxer_options), options: input_options}
  end

  # BEGIN GENERATED HELPERS
  @mov_schema %{
    "activation_bytes" => [%{type: :binary, constants: []}],
    "advanced_editlist" => [%{type: :boolean, constants: []}],
    "analyzeduration" => [%{type: :int64, constants: []}],
    "audible_fixed_key" => [%{type: :binary, constants: []}],
    "audible_iv" => [%{type: :binary, constants: []}],
    "audible_key" => [%{type: :binary, constants: []}],
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
    "decryption_key" => [%{type: :binary, constants: []}],
    "enable_drefs" => [%{type: :boolean, constants: []}],
    "export_all" => [%{type: :boolean, constants: []}],
    "export_xmp" => [%{type: :boolean, constants: []}],
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
    "ignore_chapters" => [%{type: :boolean, constants: []}],
    "ignore_editlist" => [%{type: :boolean, constants: []}],
    "interleaved_read" => [%{type: :boolean, constants: []}],
    "max_delay" => [%{type: :int, constants: []}],
    "max_stts_delta" => [%{type: :int, constants: []}],
    "probesize" => [%{type: :int64, constants: []}],
    "seek_streams_individually" => [%{type: :boolean, constants: []}],
    "use_absolute_path" => [%{type: :boolean, constants: []}],
    "use_mfra_for" => [%{type: :int, constants: ["auto", "dts", "pts"]}],
    "use_tfdt" => [%{type: :boolean, constants: []}]
  }
  @type mov_option ::
          {:activation_bytes, String.t() | atom()}
          | {:advanced_editlist, boolean() | :auto | String.t()}
          | {:analyzeduration, integer() | String.t()}
          | {:audible_fixed_key, String.t() | atom()}
          | {:audible_iv, String.t() | atom()}
          | {:audible_key, String.t() | atom()}
          | {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
          | {:decryption_key, String.t() | atom()}
          | {:enable_drefs, boolean() | :auto | String.t()}
          | {:export_all, boolean() | :auto | String.t()}
          | {:export_xmp, boolean() | :auto | String.t()}
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
          | {:ignore_chapters, boolean() | :auto | String.t()}
          | {:ignore_editlist, boolean() | :auto | String.t()}
          | {:interleaved_read, boolean() | :auto | String.t()}
          | {:max_delay, integer() | String.t()}
          | {:max_stts_delta, integer() | String.t()}
          | {:probesize, integer() | String.t()}
          | {:seek_streams_individually, boolean() | :auto | String.t()}
          | {:use_absolute_path, boolean() | :auto | String.t()}
          | {:use_mfra_for, integer() | String.t() | :auto | :dts | :pts}
          | {:use_tfdt, boolean() | :auto | String.t()}
          | {:raw, [Command.av_option()]}
          | {:input_options, [Command.option()]}
  @doc """
  mov: QuickTime / MOV

  Builds an input declaration. Raw CLI controls go in input_options.

    * Common extensions: mov,mp4,m4a,3gp,3g2,mj2,psp,m4b,ism,ismv,isma,f4v,avif,heic,heif.

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `use_absolute_path` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): allow using absolute path when opening alias, this is a possible security issue (default false)
    * `seek_streams_individually` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Seek each stream individually to the closest point (default true)
    * `ignore_editlist` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Ignore the edit list atom. (default false)
    * `advanced_editlist` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Modify the AVIndex according to the editlists. Use this option to decode in the order specified by the edits. (default true)
    * `ignore_chapters` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): (default false)
    * `use_mfra_for` (mov,mp4,m4a,3gp,3g2,mj2, :int): use mfra for fragment timestamps (from -1 to 2) (default auto) Reported constants: auto, dts, pts.
    * `use_tfdt` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): use tfdt for fragment timestamps (default true)
    * `export_all` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Export unrecognized metadata entries (default false)
    * `export_xmp` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Export full XMP metadata (default false)
    * `activation_bytes` (mov,mp4,m4a,3gp,3g2,mj2, :binary): Secret bytes for Audible AAX files
    * `audible_key` (mov,mp4,m4a,3gp,3g2,mj2, :binary): AES-128 Key for Audible AAXC files
    * `audible_iv` (mov,mp4,m4a,3gp,3g2,mj2, :binary): AES-128 IV for Audible AAXC files
    * `audible_fixed_key` (mov,mp4,m4a,3gp,3g2,mj2, :binary): Fixed key used for handling Audible AAX files
    * `decryption_key` (mov,mp4,m4a,3gp,3g2,mj2, :binary): The media decryption key (hex)
    * `enable_drefs` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Enable external track support. (default false)
    * `max_stts_delta` (mov,mp4,m4a,3gp,3g2,mj2, :int): treat offsets above this value as invalid (from 0 to UINT32_MAX) (default 4294487295)
    * `interleaved_read` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Interleave packets from multiple tracks at demuxer level (default true)
    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `probesize` (AVFormatContext, :int64): set probing size (from 32 to I64_MAX) (default 5000000)
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `analyzeduration` (AVFormatContext, :int64): specify how many microseconds are analyzed to probe the input (from 0 to I64_MAX) (default 0)
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
  """
  @spec mov(Input.source(), [mov_option()]) :: Input.t()
  def mov(source, options \\ []) do
    build_input(source, "mov", options, @mov_schema)
  end

  @mp4_schema %{
    "activation_bytes" => [%{type: :binary, constants: []}],
    "advanced_editlist" => [%{type: :boolean, constants: []}],
    "analyzeduration" => [%{type: :int64, constants: []}],
    "audible_fixed_key" => [%{type: :binary, constants: []}],
    "audible_iv" => [%{type: :binary, constants: []}],
    "audible_key" => [%{type: :binary, constants: []}],
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
    "decryption_key" => [%{type: :binary, constants: []}],
    "enable_drefs" => [%{type: :boolean, constants: []}],
    "export_all" => [%{type: :boolean, constants: []}],
    "export_xmp" => [%{type: :boolean, constants: []}],
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
    "ignore_chapters" => [%{type: :boolean, constants: []}],
    "ignore_editlist" => [%{type: :boolean, constants: []}],
    "interleaved_read" => [%{type: :boolean, constants: []}],
    "max_delay" => [%{type: :int, constants: []}],
    "max_stts_delta" => [%{type: :int, constants: []}],
    "probesize" => [%{type: :int64, constants: []}],
    "seek_streams_individually" => [%{type: :boolean, constants: []}],
    "use_absolute_path" => [%{type: :boolean, constants: []}],
    "use_mfra_for" => [%{type: :int, constants: ["auto", "dts", "pts"]}],
    "use_tfdt" => [%{type: :boolean, constants: []}]
  }
  @type mp4_option ::
          {:activation_bytes, String.t() | atom()}
          | {:advanced_editlist, boolean() | :auto | String.t()}
          | {:analyzeduration, integer() | String.t()}
          | {:audible_fixed_key, String.t() | atom()}
          | {:audible_iv, String.t() | atom()}
          | {:audible_key, String.t() | atom()}
          | {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
          | {:decryption_key, String.t() | atom()}
          | {:enable_drefs, boolean() | :auto | String.t()}
          | {:export_all, boolean() | :auto | String.t()}
          | {:export_xmp, boolean() | :auto | String.t()}
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
          | {:ignore_chapters, boolean() | :auto | String.t()}
          | {:ignore_editlist, boolean() | :auto | String.t()}
          | {:interleaved_read, boolean() | :auto | String.t()}
          | {:max_delay, integer() | String.t()}
          | {:max_stts_delta, integer() | String.t()}
          | {:probesize, integer() | String.t()}
          | {:seek_streams_individually, boolean() | :auto | String.t()}
          | {:use_absolute_path, boolean() | :auto | String.t()}
          | {:use_mfra_for, integer() | String.t() | :auto | :dts | :pts}
          | {:use_tfdt, boolean() | :auto | String.t()}
          | {:raw, [Command.av_option()]}
          | {:input_options, [Command.option()]}
  @doc """
  mp4: QuickTime / MOV

  Builds an input declaration. Raw CLI controls go in input_options.

    * Common extensions: mov,mp4,m4a,3gp,3g2,mj2,psp,m4b,ism,ismv,isma,f4v,avif,heic,heif.

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `use_absolute_path` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): allow using absolute path when opening alias, this is a possible security issue (default false)
    * `seek_streams_individually` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Seek each stream individually to the closest point (default true)
    * `ignore_editlist` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Ignore the edit list atom. (default false)
    * `advanced_editlist` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Modify the AVIndex according to the editlists. Use this option to decode in the order specified by the edits. (default true)
    * `ignore_chapters` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): (default false)
    * `use_mfra_for` (mov,mp4,m4a,3gp,3g2,mj2, :int): use mfra for fragment timestamps (from -1 to 2) (default auto) Reported constants: auto, dts, pts.
    * `use_tfdt` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): use tfdt for fragment timestamps (default true)
    * `export_all` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Export unrecognized metadata entries (default false)
    * `export_xmp` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Export full XMP metadata (default false)
    * `activation_bytes` (mov,mp4,m4a,3gp,3g2,mj2, :binary): Secret bytes for Audible AAX files
    * `audible_key` (mov,mp4,m4a,3gp,3g2,mj2, :binary): AES-128 Key for Audible AAXC files
    * `audible_iv` (mov,mp4,m4a,3gp,3g2,mj2, :binary): AES-128 IV for Audible AAXC files
    * `audible_fixed_key` (mov,mp4,m4a,3gp,3g2,mj2, :binary): Fixed key used for handling Audible AAX files
    * `decryption_key` (mov,mp4,m4a,3gp,3g2,mj2, :binary): The media decryption key (hex)
    * `enable_drefs` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Enable external track support. (default false)
    * `max_stts_delta` (mov,mp4,m4a,3gp,3g2,mj2, :int): treat offsets above this value as invalid (from 0 to UINT32_MAX) (default 4294487295)
    * `interleaved_read` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Interleave packets from multiple tracks at demuxer level (default true)
    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `probesize` (AVFormatContext, :int64): set probing size (from 32 to I64_MAX) (default 5000000)
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `analyzeduration` (AVFormatContext, :int64): specify how many microseconds are analyzed to probe the input (from 0 to I64_MAX) (default 0)
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
  """
  @spec mp4(Input.source(), [mp4_option()]) :: Input.t()
  def mp4(source, options \\ []) do
    build_input(source, "mp4", options, @mp4_schema)
  end

  @m4a_schema %{
    "activation_bytes" => [%{type: :binary, constants: []}],
    "advanced_editlist" => [%{type: :boolean, constants: []}],
    "analyzeduration" => [%{type: :int64, constants: []}],
    "audible_fixed_key" => [%{type: :binary, constants: []}],
    "audible_iv" => [%{type: :binary, constants: []}],
    "audible_key" => [%{type: :binary, constants: []}],
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
    "decryption_key" => [%{type: :binary, constants: []}],
    "enable_drefs" => [%{type: :boolean, constants: []}],
    "export_all" => [%{type: :boolean, constants: []}],
    "export_xmp" => [%{type: :boolean, constants: []}],
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
    "ignore_chapters" => [%{type: :boolean, constants: []}],
    "ignore_editlist" => [%{type: :boolean, constants: []}],
    "interleaved_read" => [%{type: :boolean, constants: []}],
    "max_delay" => [%{type: :int, constants: []}],
    "max_stts_delta" => [%{type: :int, constants: []}],
    "probesize" => [%{type: :int64, constants: []}],
    "seek_streams_individually" => [%{type: :boolean, constants: []}],
    "use_absolute_path" => [%{type: :boolean, constants: []}],
    "use_mfra_for" => [%{type: :int, constants: ["auto", "dts", "pts"]}],
    "use_tfdt" => [%{type: :boolean, constants: []}]
  }
  @type m4a_option ::
          {:activation_bytes, String.t() | atom()}
          | {:advanced_editlist, boolean() | :auto | String.t()}
          | {:analyzeduration, integer() | String.t()}
          | {:audible_fixed_key, String.t() | atom()}
          | {:audible_iv, String.t() | atom()}
          | {:audible_key, String.t() | atom()}
          | {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
          | {:decryption_key, String.t() | atom()}
          | {:enable_drefs, boolean() | :auto | String.t()}
          | {:export_all, boolean() | :auto | String.t()}
          | {:export_xmp, boolean() | :auto | String.t()}
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
          | {:ignore_chapters, boolean() | :auto | String.t()}
          | {:ignore_editlist, boolean() | :auto | String.t()}
          | {:interleaved_read, boolean() | :auto | String.t()}
          | {:max_delay, integer() | String.t()}
          | {:max_stts_delta, integer() | String.t()}
          | {:probesize, integer() | String.t()}
          | {:seek_streams_individually, boolean() | :auto | String.t()}
          | {:use_absolute_path, boolean() | :auto | String.t()}
          | {:use_mfra_for, integer() | String.t() | :auto | :dts | :pts}
          | {:use_tfdt, boolean() | :auto | String.t()}
          | {:raw, [Command.av_option()]}
          | {:input_options, [Command.option()]}
  @doc """
  m4a: QuickTime / MOV

  Builds an input declaration. Raw CLI controls go in input_options.

    * Common extensions: mov,mp4,m4a,3gp,3g2,mj2,psp,m4b,ism,ismv,isma,f4v,avif,heic,heif.

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `use_absolute_path` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): allow using absolute path when opening alias, this is a possible security issue (default false)
    * `seek_streams_individually` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Seek each stream individually to the closest point (default true)
    * `ignore_editlist` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Ignore the edit list atom. (default false)
    * `advanced_editlist` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Modify the AVIndex according to the editlists. Use this option to decode in the order specified by the edits. (default true)
    * `ignore_chapters` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): (default false)
    * `use_mfra_for` (mov,mp4,m4a,3gp,3g2,mj2, :int): use mfra for fragment timestamps (from -1 to 2) (default auto) Reported constants: auto, dts, pts.
    * `use_tfdt` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): use tfdt for fragment timestamps (default true)
    * `export_all` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Export unrecognized metadata entries (default false)
    * `export_xmp` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Export full XMP metadata (default false)
    * `activation_bytes` (mov,mp4,m4a,3gp,3g2,mj2, :binary): Secret bytes for Audible AAX files
    * `audible_key` (mov,mp4,m4a,3gp,3g2,mj2, :binary): AES-128 Key for Audible AAXC files
    * `audible_iv` (mov,mp4,m4a,3gp,3g2,mj2, :binary): AES-128 IV for Audible AAXC files
    * `audible_fixed_key` (mov,mp4,m4a,3gp,3g2,mj2, :binary): Fixed key used for handling Audible AAX files
    * `decryption_key` (mov,mp4,m4a,3gp,3g2,mj2, :binary): The media decryption key (hex)
    * `enable_drefs` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Enable external track support. (default false)
    * `max_stts_delta` (mov,mp4,m4a,3gp,3g2,mj2, :int): treat offsets above this value as invalid (from 0 to UINT32_MAX) (default 4294487295)
    * `interleaved_read` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Interleave packets from multiple tracks at demuxer level (default true)
    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `probesize` (AVFormatContext, :int64): set probing size (from 32 to I64_MAX) (default 5000000)
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `analyzeduration` (AVFormatContext, :int64): specify how many microseconds are analyzed to probe the input (from 0 to I64_MAX) (default 0)
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
  """
  @spec m4a(Input.source(), [m4a_option()]) :: Input.t()
  def m4a(source, options \\ []) do
    build_input(source, "m4a", options, @m4a_schema)
  end

  @mj2_schema %{
    "activation_bytes" => [%{type: :binary, constants: []}],
    "advanced_editlist" => [%{type: :boolean, constants: []}],
    "analyzeduration" => [%{type: :int64, constants: []}],
    "audible_fixed_key" => [%{type: :binary, constants: []}],
    "audible_iv" => [%{type: :binary, constants: []}],
    "audible_key" => [%{type: :binary, constants: []}],
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
    "decryption_key" => [%{type: :binary, constants: []}],
    "enable_drefs" => [%{type: :boolean, constants: []}],
    "export_all" => [%{type: :boolean, constants: []}],
    "export_xmp" => [%{type: :boolean, constants: []}],
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
    "ignore_chapters" => [%{type: :boolean, constants: []}],
    "ignore_editlist" => [%{type: :boolean, constants: []}],
    "interleaved_read" => [%{type: :boolean, constants: []}],
    "max_delay" => [%{type: :int, constants: []}],
    "max_stts_delta" => [%{type: :int, constants: []}],
    "probesize" => [%{type: :int64, constants: []}],
    "seek_streams_individually" => [%{type: :boolean, constants: []}],
    "use_absolute_path" => [%{type: :boolean, constants: []}],
    "use_mfra_for" => [%{type: :int, constants: ["auto", "dts", "pts"]}],
    "use_tfdt" => [%{type: :boolean, constants: []}]
  }
  @type mj2_option ::
          {:activation_bytes, String.t() | atom()}
          | {:advanced_editlist, boolean() | :auto | String.t()}
          | {:analyzeduration, integer() | String.t()}
          | {:audible_fixed_key, String.t() | atom()}
          | {:audible_iv, String.t() | atom()}
          | {:audible_key, String.t() | atom()}
          | {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
          | {:decryption_key, String.t() | atom()}
          | {:enable_drefs, boolean() | :auto | String.t()}
          | {:export_all, boolean() | :auto | String.t()}
          | {:export_xmp, boolean() | :auto | String.t()}
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
          | {:ignore_chapters, boolean() | :auto | String.t()}
          | {:ignore_editlist, boolean() | :auto | String.t()}
          | {:interleaved_read, boolean() | :auto | String.t()}
          | {:max_delay, integer() | String.t()}
          | {:max_stts_delta, integer() | String.t()}
          | {:probesize, integer() | String.t()}
          | {:seek_streams_individually, boolean() | :auto | String.t()}
          | {:use_absolute_path, boolean() | :auto | String.t()}
          | {:use_mfra_for, integer() | String.t() | :auto | :dts | :pts}
          | {:use_tfdt, boolean() | :auto | String.t()}
          | {:raw, [Command.av_option()]}
          | {:input_options, [Command.option()]}
  @doc """
  mj2: QuickTime / MOV

  Builds an input declaration. Raw CLI controls go in input_options.

    * Common extensions: mov,mp4,m4a,3gp,3g2,mj2,psp,m4b,ism,ismv,isma,f4v,avif,heic,heif.

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `use_absolute_path` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): allow using absolute path when opening alias, this is a possible security issue (default false)
    * `seek_streams_individually` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Seek each stream individually to the closest point (default true)
    * `ignore_editlist` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Ignore the edit list atom. (default false)
    * `advanced_editlist` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Modify the AVIndex according to the editlists. Use this option to decode in the order specified by the edits. (default true)
    * `ignore_chapters` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): (default false)
    * `use_mfra_for` (mov,mp4,m4a,3gp,3g2,mj2, :int): use mfra for fragment timestamps (from -1 to 2) (default auto) Reported constants: auto, dts, pts.
    * `use_tfdt` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): use tfdt for fragment timestamps (default true)
    * `export_all` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Export unrecognized metadata entries (default false)
    * `export_xmp` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Export full XMP metadata (default false)
    * `activation_bytes` (mov,mp4,m4a,3gp,3g2,mj2, :binary): Secret bytes for Audible AAX files
    * `audible_key` (mov,mp4,m4a,3gp,3g2,mj2, :binary): AES-128 Key for Audible AAXC files
    * `audible_iv` (mov,mp4,m4a,3gp,3g2,mj2, :binary): AES-128 IV for Audible AAXC files
    * `audible_fixed_key` (mov,mp4,m4a,3gp,3g2,mj2, :binary): Fixed key used for handling Audible AAX files
    * `decryption_key` (mov,mp4,m4a,3gp,3g2,mj2, :binary): The media decryption key (hex)
    * `enable_drefs` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Enable external track support. (default false)
    * `max_stts_delta` (mov,mp4,m4a,3gp,3g2,mj2, :int): treat offsets above this value as invalid (from 0 to UINT32_MAX) (default 4294487295)
    * `interleaved_read` (mov,mp4,m4a,3gp,3g2,mj2, :boolean): Interleave packets from multiple tracks at demuxer level (default true)
    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `probesize` (AVFormatContext, :int64): set probing size (from 32 to I64_MAX) (default 5000000)
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `analyzeduration` (AVFormatContext, :int64): specify how many microseconds are analyzed to probe the input (from 0 to I64_MAX) (default 0)
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
  """
  @spec mj2(Input.source(), [mj2_option()]) :: Input.t()
  def mj2(source, options \\ []) do
    build_input(source, "mj2", options, @mj2_schema)
  end

  @matroska_schema %{
    "analyzeduration" => [%{type: :int64, constants: []}],
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
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
    "max_delay" => [%{type: :int, constants: []}],
    "probesize" => [%{type: :int64, constants: []}]
  }
  @type matroska_option ::
          {:analyzeduration, integer() | String.t()}
          | {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
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
          | {:max_delay, integer() | String.t()}
          | {:probesize, integer() | String.t()}
          | {:raw, [Command.av_option()]}
          | {:input_options, [Command.option()]}
  @doc """
  matroska: Matroska / WebM

  Builds an input declaration. Raw CLI controls go in input_options.

    * Common extensions: mkv,mk3d,mka,mks,webm.

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `probesize` (AVFormatContext, :int64): set probing size (from 32 to I64_MAX) (default 5000000)
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `analyzeduration` (AVFormatContext, :int64): specify how many microseconds are analyzed to probe the input (from 0 to I64_MAX) (default 0)
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
  """
  @spec matroska(Input.source(), [matroska_option()]) :: Input.t()
  def matroska(source, options \\ []) do
    build_input(source, "matroska", options, @matroska_schema)
  end

  @webm_schema %{
    "analyzeduration" => [%{type: :int64, constants: []}],
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
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
    "max_delay" => [%{type: :int, constants: []}],
    "probesize" => [%{type: :int64, constants: []}]
  }
  @type webm_option ::
          {:analyzeduration, integer() | String.t()}
          | {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
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
          | {:max_delay, integer() | String.t()}
          | {:probesize, integer() | String.t()}
          | {:raw, [Command.av_option()]}
          | {:input_options, [Command.option()]}
  @doc """
  webm: Matroska / WebM

  Builds an input declaration. Raw CLI controls go in input_options.

    * Common extensions: mkv,mk3d,mka,mks,webm.

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `probesize` (AVFormatContext, :int64): set probing size (from 32 to I64_MAX) (default 5000000)
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `analyzeduration` (AVFormatContext, :int64): specify how many microseconds are analyzed to probe the input (from 0 to I64_MAX) (default 0)
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
  """
  @spec webm(Input.source(), [webm_option()]) :: Input.t()
  def webm(source, options \\ []) do
    build_input(source, "webm", options, @webm_schema)
  end

  @rawvideo_schema %{
    "analyzeduration" => [%{type: :int64, constants: []}],
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
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
    "framerate" => [%{type: :video_rate, constants: []}],
    "max_delay" => [%{type: :int, constants: []}],
    "pixel_format" => [%{type: :string, constants: []}],
    "probesize" => [%{type: :int64, constants: []}],
    "video_size" => [%{type: :image_size, constants: []}]
  }
  @type rawvideo_option ::
          {:analyzeduration, integer() | String.t()}
          | {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
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
          | {:framerate, number() | String.t()}
          | {:max_delay, integer() | String.t()}
          | {:pixel_format, String.t() | atom()}
          | {:probesize, integer() | String.t()}
          | {:video_size, String.t() | atom()}
          | {:raw, [Command.av_option()]}
          | {:input_options, [Command.option()]}
  @doc """
  rawvideo: raw video

  Builds an input declaration. Raw CLI controls go in input_options.

    * Common extensions: yuv,cif,qcif,rgb.

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `pixel_format` (rawvideo demuxer, :string): set pixel format (default \"yuv420p\")
    * `video_size` (rawvideo demuxer, :image_size): set frame size
    * `framerate` (rawvideo demuxer, :video_rate): set frame rate (default \"25\")
    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `probesize` (AVFormatContext, :int64): set probing size (from 32 to I64_MAX) (default 5000000)
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `analyzeduration` (AVFormatContext, :int64): specify how many microseconds are analyzed to probe the input (from 0 to I64_MAX) (default 0)
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
  """
  @spec rawvideo(Input.source(), [rawvideo_option()]) :: Input.t()
  def rawvideo(source, options \\ []) do
    build_input(source, "rawvideo", options, @rawvideo_schema)
  end

  @s16le_schema %{
    "analyzeduration" => [%{type: :int64, constants: []}],
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
    "ch_layout" => [%{type: :channel_layout, constants: []}],
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
    "max_delay" => [%{type: :int, constants: []}],
    "probesize" => [%{type: :int64, constants: []}],
    "sample_rate" => [%{type: :int, constants: []}]
  }
  @type s16le_option ::
          {:analyzeduration, integer() | String.t()}
          | {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
          | {:ch_layout, String.t() | atom()}
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
          | {:max_delay, integer() | String.t()}
          | {:probesize, integer() | String.t()}
          | {:sample_rate, integer() | String.t()}
          | {:raw, [Command.av_option()]}
          | {:input_options, [Command.option()]}
  @doc """
  s16le: PCM signed 16-bit little-endian

  Builds an input declaration. Raw CLI controls go in input_options.

    * Common extensions: sw.

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `sample_rate` (pcm demuxer, :int): (from 0 to INT_MAX) (default 44100)
    * `ch_layout` (pcm demuxer, :channel_layout): (default \"mono\")
    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `probesize` (AVFormatContext, :int64): set probing size (from 32 to I64_MAX) (default 5000000)
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `analyzeduration` (AVFormatContext, :int64): specify how many microseconds are analyzed to probe the input (from 0 to I64_MAX) (default 0)
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
  """
  @spec s16le(Input.source(), [s16le_option()]) :: Input.t()
  def s16le(source, options \\ []) do
    build_input(source, "s16le", options, @s16le_schema)
  end

  @lavfi_schema %{
    "analyzeduration" => [%{type: :int64, constants: []}],
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
    "dumpgraph" => [%{type: :string, constants: []}],
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
    "graph" => [%{type: :string, constants: []}],
    "graph_file" => [%{type: :string, constants: []}],
    "max_delay" => [%{type: :int, constants: []}],
    "probesize" => [%{type: :int64, constants: []}]
  }
  @type lavfi_option ::
          {:analyzeduration, integer() | String.t()}
          | {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
          | {:dumpgraph, String.t() | atom()}
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
          | {:graph, String.t() | atom()}
          | {:graph_file, String.t() | atom()}
          | {:max_delay, integer() | String.t()}
          | {:probesize, integer() | String.t()}
          | {:raw, [Command.av_option()]}
          | {:input_options, [Command.option()]}
  @doc """
  lavfi: Libavfilter virtual input device

  Builds an input declaration. Raw CLI controls go in input_options.



  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `graph` (lavfi indev, :string): set libavfilter graph
    * `graph_file` (lavfi indev, :string): set libavfilter graph filename
    * `dumpgraph` (lavfi indev, :string): dump graph to stderr
    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `probesize` (AVFormatContext, :int64): set probing size (from 32 to I64_MAX) (default 5000000)
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `analyzeduration` (AVFormatContext, :int64): specify how many microseconds are analyzed to probe the input (from 0 to I64_MAX) (default 0)
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
  """
  @spec lavfi(Input.source(), [lavfi_option()]) :: Input.t()
  def lavfi(source, options \\ []) do
    build_input(source, "lavfi", options, @lavfi_schema)
  end

  @mp3_schema %{
    "analyzeduration" => [%{type: :int64, constants: []}],
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
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
    "max_delay" => [%{type: :int, constants: []}],
    "probesize" => [%{type: :int64, constants: []}],
    "usetoc" => [%{type: :boolean, constants: []}]
  }
  @type mp3_option ::
          {:analyzeduration, integer() | String.t()}
          | {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
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
          | {:max_delay, integer() | String.t()}
          | {:probesize, integer() | String.t()}
          | {:usetoc, boolean() | :auto | String.t()}
          | {:raw, [Command.av_option()]}
          | {:input_options, [Command.option()]}
  @doc """
  mp3: MP2/3 (MPEG audio layer 2/3)

  Builds an input declaration. Raw CLI controls go in input_options.

    * Common extensions: mp2,mp3,m2a,mpa.

  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `usetoc` (mp3, :boolean): use table of contents (default false)
    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `probesize` (AVFormatContext, :int64): set probing size (from 32 to I64_MAX) (default 5000000)
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `analyzeduration` (AVFormatContext, :int64): specify how many microseconds are analyzed to probe the input (from 0 to I64_MAX) (default 0)
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
  """
  @spec mp3(Input.source(), [mp3_option()]) :: Input.t()
  def mp3(source, options \\ []) do
    build_input(source, "mp3", options, @mp3_schema)
  end

  @image2_schema %{
    "analyzeduration" => [%{type: :int64, constants: []}],
    "avioflags" => [%{type: :flags, constants: ["direct"]}],
    "export_path_metadata" => [%{type: :boolean, constants: []}],
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
    "framerate" => [%{type: :video_rate, constants: []}],
    "loop" => [%{type: :boolean, constants: []}],
    "max_delay" => [%{type: :int, constants: []}],
    "pattern_type" => [%{type: :int, constants: ["glob_sequence", "glob", "sequence", "none"]}],
    "pixel_format" => [%{type: :string, constants: []}],
    "probesize" => [%{type: :int64, constants: []}],
    "start_number" => [%{type: :int, constants: []}],
    "start_number_range" => [%{type: :int, constants: []}],
    "ts_from_file" => [%{type: :int, constants: ["none", "sec", "ns"]}],
    "video_size" => [%{type: :image_size, constants: []}]
  }
  @type image2_option ::
          {:analyzeduration, integer() | String.t()}
          | {:avioflags, integer() | String.t() | [String.t() | :direct] | :direct}
          | {:export_path_metadata, boolean() | :auto | String.t()}
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
          | {:framerate, number() | String.t()}
          | {:loop, boolean() | :auto | String.t()}
          | {:max_delay, integer() | String.t()}
          | {:pattern_type, integer() | String.t() | :glob_sequence | :glob | :sequence | :none}
          | {:pixel_format, String.t() | atom()}
          | {:probesize, integer() | String.t()}
          | {:start_number, integer() | String.t()}
          | {:start_number_range, integer() | String.t()}
          | {:ts_from_file, integer() | String.t() | :none | :sec | :ns}
          | {:video_size, String.t() | atom()}
          | {:raw, [Command.av_option()]}
          | {:input_options, [Command.option()]}
  @doc """
  image2: image2 sequence

  Builds an input declaration. Raw CLI controls go in input_options.



  Metadata baseline: FFmpeg 7.1.5. Option defaults/ranges below are reported
  metadata, not emitted defaults or a complete validator. Strings remain an
  escape hatch for FFmpeg expressions; use `raw:` for unlisted option names.

  ## Options

    * `pattern_type` (image2 demuxer, :int): set pattern type (from 0 to INT_MAX) (default 4) Reported constants: glob_sequence, glob, sequence, none.
    * `start_number` (image2 demuxer, :int): set first number in the sequence (from INT_MIN to INT_MAX) (default 0)
    * `start_number_range` (image2 demuxer, :int): set range for looking at the first sequence number (from 1 to INT_MAX) (default 5)
    * `ts_from_file` (image2 demuxer, :int): set frame timestamp from file's one (from 0 to 2) (default none) Reported constants: none, sec, ns.
    * `export_path_metadata` (image2 demuxer, :boolean): enable metadata containing input path information (default false)
    * `framerate` (image2 demuxer, :video_rate): set the video framerate (default \"25\")
    * `pixel_format` (image2 demuxer, :string): set video pixel format
    * `video_size` (image2 demuxer, :image_size): set video size
    * `loop` (image2 demuxer, :boolean): force loop over input file sequence (default false)
    * `avioflags` (AVFormatContext, :flags): (default 0) Reported constants: direct.
    * `probesize` (AVFormatContext, :int64): set probing size (from 32 to I64_MAX) (default 5000000)
    * `fflags` (AVFormatContext, :flags): (default autobsf) Reported constants: flush_packets, ignidx, genpts, nofillin, noparse, igndts, discardcorrupt, sortdts, fastseek, nobuffer, bitexact, shortest, autobsf.
    * `analyzeduration` (AVFormatContext, :int64): specify how many microseconds are analyzed to probe the input (from 0 to I64_MAX) (default 0)
    * `max_delay` (AVFormatContext, :int): maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)
  """
  @spec image2(Input.source(), [image2_option()]) :: Input.t()
  def image2(source, options \\ []) do
    build_input(source, "image2", options, @image2_schema)
  end

  # END GENERATED HELPERS
end
