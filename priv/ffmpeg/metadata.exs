%{
  version: %{
    raw:
      "ffmpeg version 7.1.5 Copyright (c) 2000-2026 the FFmpeg developers\nbuilt with gcc 15 (GCC)\nconfiguration: --prefix=/usr --bindir=/usr/bin --datadir=/usr/share/ffmpeg --docdir=/usr/share/doc/ffmpeg --incdir=/usr/include/ffmpeg --libdir=/usr/lib64 --mandir=/usr/share/man --arch=x86_64 --optflags='-O2 -flto=auto -ffat-lto-objects -fexceptions -g -grecord-gcc-switches -pipe -Wall -Wno-complain-wrong-lang -Werror=format-security -Wp,-U_FORTIFY_SOURCE,-D_FORTIFY_SOURCE=3 -Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -fstack-protector-strong -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 -m64 -march=x86-64 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection -mtls-dialect=gnu2 -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer' --extra-ldflags='-Wl,-z,relro -Wl,--as-needed -Wl,-z,pack-relative-relocs -Wl,-z,now -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -specs=/usr/lib/rpm/redhat/redhat-hardened-ld-errors -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 -Wl,--build-id=sha1 -specs=/usr/lib/rpm/redhat/redhat-package-notes ' --extra-cflags=' -I/usr/include/rav1e' --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-libvo-amrwbenc --enable-version3 --enable-bzlib --enable-chromaprint --enable-fontconfig --enable-frei0r --enable-gcrypt --enable-gnutls --enable-ladspa --enable-lcms2 --enable-libaom --enable-libaribb24 --enable-libaribcaption --enable-libdav1d --enable-libass --enable-libbluray --enable-libbs2b --enable-libcodec2 --enable-libcdio --enable-libdrm --enable-libjack --enable-libjxl --enable-libfreetype --enable-libfribidi --enable-libgme --enable-libgsm --enable-libharfbuzz --enable-libilbc --enable-liblc3 --enable-libmp3lame --enable-libmysofa --enable-nvenc --enable-openal --enable-opencl --enable-opengl --enable-libopenh264 --enable-libopenjpeg --enable-libopenmpt --enable-libopus --enable-libpulse --enable-libplacebo --enable-librsvg --enable-librav1e --enable-librubberband --enable-libqrencode --enable-libsmbclient --enable-version3 --enable-libsnappy --enable-libsoxr --enable-libspeex --enable-libsrt --enable-libssh --enable-libsvtav1 --enable-libtesseract --enable-libtheora --enable-libtwolame --enable-libvorbis --enable-libv4l2 --enable-libvidstab --enable-libvmaf --enable-version3 --enable-vapoursynth --enable-libvpx --enable-libvvenc --enable-vulkan --enable-libshaderc --enable-libwebp --enable-libx264 --enable-libx265 --enable-libxvid --enable-libxml2 --enable-libzimg --enable-libzmq --enable-libzvbi --enable-lv2 --enable-avfilter --enable-libmodplug --enable-postproc --enable-pthreads --disable-static --enable-shared --enable-gpl --disable-debug --disable-stripping --shlibdir=/usr/lib64 --enable-lto --enable-libvpl --enable-runtime-cpudetect\nlibavutil      59. 39.100 / 59. 39.100\nlibavcodec     61. 19.101 / 61. 19.101\nlibavformat    61.  7.103 / 61.  7.103\nlibavdevice    61.  3.100 / 61.  3.100\nlibavfilter    10.  5.100 / 10.  5.100\nlibswscale      8.  3.100 /  8.  3.100\nlibswresample   5.  3.100 /  5.  3.100\nlibpostproc    58.  3.100 / 58.  3.100\n",
    version: "7.1.5",
    executable: "/usr/bin/ffmpeg",
    configuration:
      "--prefix=/usr --bindir=/usr/bin --datadir=/usr/share/ffmpeg --docdir=/usr/share/doc/ffmpeg --incdir=/usr/include/ffmpeg --libdir=/usr/lib64 --mandir=/usr/share/man --arch=x86_64 --optflags='-O2 -flto=auto -ffat-lto-objects -fexceptions -g -grecord-gcc-switches -pipe -Wall -Wno-complain-wrong-lang -Werror=format-security -Wp,-U_FORTIFY_SOURCE,-D_FORTIFY_SOURCE=3 -Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -fstack-protector-strong -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 -m64 -march=x86-64 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection -mtls-dialect=gnu2 -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer' --extra-ldflags='-Wl,-z,relro -Wl,--as-needed -Wl,-z,pack-relative-relocs -Wl,-z,now -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -specs=/usr/lib/rpm/redhat/redhat-hardened-ld-errors -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 -Wl,--build-id=sha1 -specs=/usr/lib/rpm/redhat/redhat-package-notes ' --extra-cflags=' -I/usr/include/rav1e' --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-libvo-amrwbenc --enable-version3 --enable-bzlib --enable-chromaprint --enable-fontconfig --enable-frei0r --enable-gcrypt --enable-gnutls --enable-ladspa --enable-lcms2 --enable-libaom --enable-libaribb24 --enable-libaribcaption --enable-libdav1d --enable-libass --enable-libbluray --enable-libbs2b --enable-libcodec2 --enable-libcdio --enable-libdrm --enable-libjack --enable-libjxl --enable-libfreetype --enable-libfribidi --enable-libgme --enable-libgsm --enable-libharfbuzz --enable-libilbc --enable-liblc3 --enable-libmp3lame --enable-libmysofa --enable-nvenc --enable-openal --enable-opencl --enable-opengl --enable-libopenh264 --enable-libopenjpeg --enable-libopenmpt --enable-libopus --enable-libpulse --enable-libplacebo --enable-librsvg --enable-librav1e --enable-librubberband --enable-libqrencode --enable-libsmbclient --enable-version3 --enable-libsnappy --enable-libsoxr --enable-libspeex --enable-libsrt --enable-libssh --enable-libsvtav1 --enable-libtesseract --enable-libtheora --enable-libtwolame --enable-libvorbis --enable-libv4l2 --enable-libvidstab --enable-libvmaf --enable-version3 --enable-vapoursynth --enable-libvpx --enable-libvvenc --enable-vulkan --enable-libshaderc --enable-libwebp --enable-libx264 --enable-libx265 --enable-libxvid --enable-libxml2 --enable-libzimg --enable-libzmq --enable-libzvbi --enable-lv2 --enable-avfilter --enable-libmodplug --enable-postproc --enable-pthreads --disable-static --enable-shared --enable-gpl --disable-debug --disable-stripping --shlibdir=/usr/lib64 --enable-lto --enable-libvpl --enable-runtime-cpudetect",
    libraries: [
      {"libavutil", "59. 39.100 / 59. 39.100"},
      {"libavcodec", "61. 19.101 / 61. 19.101"},
      {"libavformat", "61. 7.103 / 61. 7.103"},
      {"libavdevice", "61. 3.100 / 61. 3.100"},
      {"libavfilter", "10. 5.100 / 10. 5.100"},
      {"libswscale", "8. 3.100 / 8. 3.100"},
      {"libswresample", "5. 3.100 / 5. 3.100"},
      {"libpostproc", "58. 3.100 / 58. 3.100"}
    ]
  },
  components: [
    %{
      description: "libx264 H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10",
      names: ["libx264"],
      kind: :encoder,
      media_type: :video,
      notes: [],
      properties: [
        {"General capabilities", "dr1 delay threads "},
        {"Threading capabilities", "other"},
        {"Supported pixel formats",
         "yuv420p yuvj420p yuv422p yuvj422p yuv444p yuvj444p nv12 nv16 nv21 yuv420p10le yuv422p10le yuv444p10le nv20le gray gray10le"}
      ],
      option_sections: [
        %{
          name: "libx264",
          options: [
            %{
              flags: "E..V.......",
              name: "preset",
              type: :string,
              help: "Set the encoding preset (cf. x264 --fullhelp) (default \"medium\")",
              ranges: [],
              constants: [],
              declared_default: "\"medium\""
            },
            %{
              flags: "E..V.......",
              name: "tune",
              type: :string,
              help: "Tune the encoding params (cf. x264 --fullhelp)",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..V.......",
              name: "profile",
              type: :string,
              help: "Set profile restrictions (cf. x264 --fullhelp)",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..V.......",
              name: "fastfirstpass",
              type: :boolean,
              help: "Use fast settings when encoding first pass (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            },
            %{
              flags: "E..V.......",
              name: "level",
              type: :string,
              help: "Specify level (as defined by Annex A)",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..V.......",
              name: "passlogfile",
              type: :string,
              help: "Filename for 2 pass stats",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..V.......",
              name: "wpredp",
              type: :string,
              help: "Weighted prediction for P-frames",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..V.......",
              name: "a53cc",
              type: :boolean,
              help: "Use A53 Closed Captions (if available) (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            },
            %{
              flags: "E..V.......",
              name: "x264opts",
              type: :string,
              help: "x264 options",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..V.......",
              name: "crf",
              type: :float,
              help:
                "Select the quality for constant quality mode (from -1 to FLT_MAX) (default -1)",
              ranges: [%{max: "FLT_MAX", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "crf_max",
              type: :float,
              help:
                "In CRF mode, prevents VBV from lowering quality beyond this point. (from -1 to FLT_MAX) (default -1)",
              ranges: [%{max: "FLT_MAX", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "qp",
              type: :int,
              help:
                "Constant quantization parameter rate control method (from -1 to INT_MAX) (default -1)",
              ranges: [%{max: "INT_MAX", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "aq-mode",
              type: :int,
              help: "AQ method (from -1 to INT_MAX) (default -1)",
              ranges: [%{max: "INT_MAX", min: "-1"}],
              constants: [
                %{flags: "E..V.......", name: "none", value: "0", help: ""},
                %{
                  flags: "E..V.......",
                  name: "variance",
                  value: "1",
                  help: "Variance AQ (complexity mask)"
                },
                %{
                  flags: "E..V.......",
                  name: "autovariance",
                  value: "2",
                  help: "Auto-variance AQ"
                },
                %{
                  flags: "E..V.......",
                  name: "autovariance-biased",
                  value: "3",
                  help: "Auto-variance AQ with bias to dark scenes"
                }
              ],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "aq-strength",
              type: :float,
              help:
                "AQ strength. Reduces blocking and blurring in flat and textured areas. (from -1 to FLT_MAX) (default -1)",
              ranges: [%{max: "FLT_MAX", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "psy",
              type: :boolean,
              help: "Use psychovisual optimizations. (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            },
            %{
              flags: "E..V.......",
              name: "psy-rd",
              type: :string,
              help: "Strength of psychovisual optimization, in <psy-rd>:<psy-trellis> format.",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..V.......",
              name: "rc-lookahead",
              type: :int,
              help:
                "Number of frames to look ahead for frametype and ratecontrol (from -1 to INT_MAX) (default -1)",
              ranges: [%{max: "INT_MAX", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "weightb",
              type: :boolean,
              help: "Weighted prediction for B-frames. (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            },
            %{
              flags: "E..V.......",
              name: "weightp",
              type: :int,
              help: "Weighted prediction analysis method. (from -1 to INT_MAX) (default -1)",
              ranges: [%{max: "INT_MAX", min: "-1"}],
              constants: [
                %{flags: "E..V.......", name: "none", value: "0", help: ""},
                %{flags: "E..V.......", name: "simple", value: "1", help: ""},
                %{flags: "E..V.......", name: "smart", value: "2", help: ""}
              ],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "ssim",
              type: :boolean,
              help: "Calculate and print SSIM stats. (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            },
            %{
              flags: "E..V.......",
              name: "intra-refresh",
              type: :boolean,
              help: "Use Periodic Intra Refresh instead of IDR frames. (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            },
            %{
              flags: "E..V.......",
              name: "bluray-compat",
              type: :boolean,
              help: "Bluray compatibility workarounds. (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            },
            %{
              flags: "E..V.......",
              name: "b-bias",
              type: :int,
              help:
                "Influences how often B-frames are used (from INT_MIN to INT_MAX) (default INT_MIN)",
              ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
              constants: [],
              declared_default: "INT_MIN"
            },
            %{
              flags: "E..V.......",
              name: "b-pyramid",
              type: :int,
              help: "Keep some B-frames as references. (from -1 to INT_MAX) (default -1)",
              ranges: [%{max: "INT_MAX", min: "-1"}],
              constants: [
                %{flags: "E..V.......", name: "none", value: "0", help: ""},
                %{
                  flags: "E..V.......",
                  name: "strict",
                  value: "1",
                  help: "Strictly hierarchical pyramid"
                },
                %{
                  flags: "E..V.......",
                  name: "normal",
                  value: "2",
                  help: "Non-strict (not Blu-ray compatible)"
                }
              ],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "mixed-refs",
              type: :boolean,
              help:
                "One reference per partition, as opposed to one reference per macroblock (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            },
            %{
              flags: "E..V.......",
              name: "8x8dct",
              type: :boolean,
              help: "High profile 8x8 transform. (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            },
            %{
              flags: "E..V.......",
              name: "fast-pskip",
              type: :boolean,
              help: "(default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            },
            %{
              flags: "E..V.......",
              name: "aud",
              type: :boolean,
              help: "Use access unit delimiters. (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            },
            %{
              flags: "E..V.......",
              name: "mbtree",
              type: :boolean,
              help: "Use macroblock tree ratecontrol. (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            },
            %{
              flags: "E..V.......",
              name: "deblock",
              type: :string,
              help: "Loop filter parameters, in <alpha:beta> form.",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..V.......",
              name: "cplxblur",
              type: :float,
              help:
                "Reduce fluctuations in QP (before curve compression) (from -1 to FLT_MAX) (default -1)",
              ranges: [%{max: "FLT_MAX", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "partitions",
              type: :string,
              help:
                "A comma-separated list of partitions to consider. Possible values: p8x8, p4x4, b8x8, i8x8, i4x4, none, all",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..V.......",
              name: "direct-pred",
              type: :int,
              help: "Direct MV prediction mode (from -1 to INT_MAX) (default -1)",
              ranges: [%{max: "INT_MAX", min: "-1"}],
              constants: [
                %{flags: "E..V.......", name: "none", value: "0", help: ""},
                %{flags: "E..V.......", name: "spatial", value: "1", help: ""},
                %{flags: "E..V.......", name: "temporal", value: "2", help: ""},
                %{flags: "E..V.......", name: "auto", value: "3", help: ""}
              ],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "slice-max-size",
              type: :int,
              help: "Limit the size of each slice in bytes (from -1 to INT_MAX) (default -1)",
              ranges: [%{max: "INT_MAX", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "stats",
              type: :string,
              help: "Filename for 2 pass stats",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..V.......",
              name: "nal-hrd",
              type: :int,
              help:
                "Signal HRD information (requires vbv-bufsize; cbr not allowed in .mp4) (from -1 to INT_MAX) (default -1)",
              ranges: [%{max: "INT_MAX", min: "-1"}],
              constants: [
                %{flags: "E..V.......", name: "none", value: "0", help: ""},
                %{flags: "E..V.......", name: "vbr", value: "1", help: ""},
                %{flags: "E..V.......", name: "cbr", value: "2", help: ""}
              ],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "avcintra-class",
              type: :int,
              help: "AVC-Intra class 50/100/200/300/480 (from -1 to 480) (default -1)",
              ranges: [%{max: "480", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "me_method",
              type: :int,
              help: "Set motion estimation method (from -1 to 4) (default -1)",
              ranges: [%{max: "4", min: "-1"}],
              constants: [
                %{flags: "E..V.......", name: "dia", value: "0", help: ""},
                %{flags: "E..V.......", name: "hex", value: "1", help: ""},
                %{flags: "E..V.......", name: "umh", value: "2", help: ""},
                %{flags: "E..V.......", name: "esa", value: "3", help: ""},
                %{flags: "E..V.......", name: "tesa", value: "4", help: ""}
              ],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "motion-est",
              type: :int,
              help: "Set motion estimation method (from -1 to 4) (default -1)",
              ranges: [%{max: "4", min: "-1"}],
              constants: [
                %{flags: "E..V.......", name: "dia", value: "0", help: ""},
                %{flags: "E..V.......", name: "hex", value: "1", help: ""},
                %{flags: "E..V.......", name: "umh", value: "2", help: ""},
                %{flags: "E..V.......", name: "esa", value: "3", help: ""},
                %{flags: "E..V.......", name: "tesa", value: "4", help: ""}
              ],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "forced-idr",
              type: :boolean,
              help: "If forcing keyframes, force them as IDR frames. (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "coder",
              type: :int,
              help: "Coder type (from -1 to 1) (default default)",
              ranges: [%{max: "1", min: "-1"}],
              constants: [
                %{flags: "E..V.......", name: "default", value: "-1", help: ""},
                %{flags: "E..V.......", name: "cavlc", value: "0", help: ""},
                %{flags: "E..V.......", name: "cabac", value: "1", help: ""},
                %{flags: "E..V.......", name: "vlc", value: "0", help: ""},
                %{flags: "E..V.......", name: "ac", value: "1", help: ""}
              ],
              declared_default: "default"
            },
            %{
              flags: "E..V.......",
              name: "b_strategy",
              type: :int,
              help: "Strategy to choose between I/P/B-frames (from -1 to 2) (default -1)",
              ranges: [%{max: "2", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "chromaoffset",
              type: :int,
              help: "QP difference between chroma and luma (from INT_MIN to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "sc_threshold",
              type: :int,
              help: "Scene change threshold (from INT_MIN to INT_MAX) (default -1)",
              ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "noise_reduction",
              type: :int,
              help: "Noise reduction (from INT_MIN to INT_MAX) (default -1)",
              ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "udu_sei",
              type: :boolean,
              help: "Use user data unregistered SEI if available (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "x264-params",
              type: :dictionary,
              help:
                "Override the x264 configuration using a :-separated list of key=value parameters",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..V.......",
              name: "mb_info",
              type: :boolean,
              help:
                "Set mb_info data through AVSideData, only useful when used from the API (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            }
          ]
        }
      ]
    },
    %{
      description: "libx265 H.265 / HEVC",
      names: ["libx265"],
      kind: :encoder,
      media_type: :video,
      notes: [],
      properties: [
        {"General capabilities", "dr1 delay threads "},
        {"Threading capabilities", "other"},
        {"Supported pixel formats",
         "yuv420p yuvj420p yuv422p yuvj422p yuv444p yuvj444p gbrp yuv420p10le yuv422p10le yuv444p10le gbrp10le yuv420p12le yuv422p12le yuv444p12le gbrp12le gray gray10le gray12le"}
      ],
      option_sections: [
        %{
          name: "libx265",
          options: [
            %{
              flags: "E..V.......",
              name: "crf",
              type: :float,
              help: "set the x265 crf (from -1 to FLT_MAX) (default -1)",
              ranges: [%{max: "FLT_MAX", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "qp",
              type: :int,
              help: "set the x265 qp (from -1 to INT_MAX) (default -1)",
              ranges: [%{max: "INT_MAX", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "forced-idr",
              type: :boolean,
              help: "if forcing keyframes, force them as IDR frames (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "preset",
              type: :string,
              help: "set the x265 preset",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..V.......",
              name: "tune",
              type: :string,
              help: "set the x265 tune parameter",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..V.......",
              name: "profile",
              type: :string,
              help: "set the x265 profile",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..V.......",
              name: "udu_sei",
              type: :boolean,
              help: "Use user data unregistered SEI if available (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "a53cc",
              type: :boolean,
              help: "Use A53 Closed Captions (if available) (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "x265-params",
              type: :dictionary,
              help: "set the x265 configuration using a :-separated list of key=value parameters",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..V.......",
              name: "dolbyvision",
              type: :boolean,
              help: "Enable Dolby Vision RPU coding (default auto)",
              ranges: [],
              constants: [
                %{flags: "E..V.......", name: "auto", value: nil, help: ""}
              ],
              declared_default: "auto"
            }
          ]
        }
      ]
    },
    %{
      description: "NVIDIA NVENC H.264 encoder",
      names: ["h264_nvenc"],
      kind: :encoder,
      media_type: :video,
      notes: [],
      properties: [
        {"General capabilities", "dr1 delay hardware "},
        {"Threading capabilities", "none"},
        {"Supported hardware devices", "cuda cuda "},
        {"Supported pixel formats",
         "yuv420p nv12 p010le yuv444p p016le yuv444p16le bgr0 bgra rgb0 rgba x2rgb10le x2bgr10le gbrp gbrp16le cuda"}
      ],
      option_sections: [
        %{
          name: "h264_nvenc",
          options: [
            %{
              flags: "E..V.......",
              name: "preset",
              type: :int,
              help: "Set the encoding preset (from 0 to 18) (default p4)",
              ranges: [%{max: "18", min: "0"}],
              constants: [
                %{flags: "E..V.......", name: "default", value: "0", help: ""},
                %{
                  flags: "E..V.......",
                  name: "slow",
                  value: "1",
                  help: "hq 2 passes"
                },
                %{
                  flags: "E..V.......",
                  name: "medium",
                  value: "2",
                  help: "hq 1 pass"
                },
                %{
                  flags: "E..V.......",
                  name: "fast",
                  value: "3",
                  help: "hp 1 pass"
                },
                %{flags: "E..V.......", name: "hp", value: "4", help: ""},
                %{flags: "E..V.......", name: "hq", value: "5", help: ""},
                %{flags: "E..V.......", name: "bd", value: "6", help: ""},
                %{
                  flags: "E..V.......",
                  name: "ll",
                  value: "7",
                  help: "low latency"
                },
                %{
                  flags: "E..V.......",
                  name: "llhq",
                  value: "8",
                  help: "low latency hq"
                },
                %{
                  flags: "E..V.......",
                  name: "llhp",
                  value: "9",
                  help: "low latency hp"
                },
                %{flags: "E..V.......", name: "lossless", value: "10", help: ""},
                %{
                  flags: "E..V.......",
                  name: "losslesshp",
                  value: "11",
                  help: ""
                },
                %{
                  flags: "E..V.......",
                  name: "p1",
                  value: "12",
                  help: "fastest (lowest quality)"
                },
                %{
                  flags: "E..V.......",
                  name: "p2",
                  value: "13",
                  help: "faster (lower quality)"
                },
                %{
                  flags: "E..V.......",
                  name: "p3",
                  value: "14",
                  help: "fast (low quality)"
                },
                %{
                  flags: "E..V.......",
                  name: "p4",
                  value: "15",
                  help: "medium (default)"
                },
                %{
                  flags: "E..V.......",
                  name: "p5",
                  value: "16",
                  help: "slow (good quality)"
                },
                %{
                  flags: "E..V.......",
                  name: "p6",
                  value: "17",
                  help: "slower (better quality)"
                },
                %{
                  flags: "E..V.......",
                  name: "p7",
                  value: "18",
                  help: "slowest (best quality)"
                }
              ],
              declared_default: "p4"
            },
            %{
              flags: "E..V.......",
              name: "tune",
              type: :int,
              help: "Set the encoding tuning info (from 1 to 4) (default hq)",
              ranges: [%{max: "4", min: "1"}],
              constants: [
                %{
                  flags: "E..V.......",
                  name: "hq",
                  value: "1",
                  help: "High quality"
                },
                %{
                  flags: "E..V.......",
                  name: "ll",
                  value: "2",
                  help: "Low latency"
                },
                %{
                  flags: "E..V.......",
                  name: "ull",
                  value: "3",
                  help: "Ultra low latency"
                },
                %{
                  flags: "E..V.......",
                  name: "lossless",
                  value: "4",
                  help: "Lossless"
                }
              ],
              declared_default: "hq"
            },
            %{
              flags: "E..V.......",
              name: "profile",
              type: :int,
              help: "Set the encoding profile (from 0 to 3) (default main)",
              ranges: [%{max: "3", min: "0"}],
              constants: [
                %{flags: "E..V.......", name: "baseline", value: "0", help: ""},
                %{flags: "E..V.......", name: "main", value: "1", help: ""},
                %{flags: "E..V.......", name: "high", value: "2", help: ""},
                %{flags: "E..V.......", name: "high444p", value: "3", help: ""}
              ],
              declared_default: "main"
            },
            %{
              flags: "E..V.......",
              name: "level",
              type: :int,
              help: "Set the encoding level restriction (from 0 to 62) (default auto)",
              ranges: [%{max: "62", min: "0"}],
              constants: [
                %{flags: "E..V.......", name: "auto", value: "0", help: ""},
                %{flags: "E..V.......", name: "1", value: "10", help: ""},
                %{flags: "E..V.......", name: "1.0", value: "10", help: ""},
                %{flags: "E..V.......", name: "1b", value: "9", help: ""},
                %{flags: "E..V.......", name: "1.0b", value: "9", help: ""},
                %{flags: "E..V.......", name: "1.1", value: "11", help: ""},
                %{flags: "E..V.......", name: "1.2", value: "12", help: ""},
                %{flags: "E..V.......", name: "1.3", value: "13", help: ""},
                %{flags: "E..V.......", name: "2", value: "20", help: ""},
                %{flags: "E..V.......", name: "2.0", value: "20", help: ""},
                %{flags: "E..V.......", name: "2.1", value: "21", help: ""},
                %{flags: "E..V.......", name: "2.2", value: "22", help: ""},
                %{flags: "E..V.......", name: "3", value: "30", help: ""},
                %{flags: "E..V.......", name: "3.0", value: "30", help: ""},
                %{flags: "E..V.......", name: "3.1", value: "31", help: ""},
                %{flags: "E..V.......", name: "3.2", value: "32", help: ""},
                %{flags: "E..V.......", name: "4", value: "40", help: ""},
                %{flags: "E..V.......", name: "4.0", value: "40", help: ""},
                %{flags: "E..V.......", name: "4.1", value: "41", help: ""},
                %{flags: "E..V.......", name: "4.2", value: "42", help: ""},
                %{flags: "E..V.......", name: "5", value: "50", help: ""},
                %{flags: "E..V.......", name: "5.0", value: "50", help: ""},
                %{flags: "E..V.......", name: "5.1", value: "51", help: ""},
                %{flags: "E..V.......", name: "5.2", value: "52", help: ""},
                %{flags: "E..V.......", name: "6.0", value: "60", help: ""},
                %{flags: "E..V.......", name: "6.1", value: "61", help: ""},
                %{flags: "E..V.......", name: "6.2", value: "62", help: ""}
              ],
              declared_default: "auto"
            },
            %{
              flags: "E..V.......",
              name: "rc",
              type: :int,
              help: "Override the preset rate-control (from -1 to INT_MAX) (default -1)",
              ranges: [%{max: "INT_MAX", min: "-1"}],
              constants: [
                %{
                  flags: "E..V.......",
                  name: "constqp",
                  value: "0",
                  help: "Constant QP mode"
                },
                %{
                  flags: "E..V.......",
                  name: "vbr",
                  value: "1",
                  help: "Variable bitrate mode"
                },
                %{
                  flags: "E..V.......",
                  name: "cbr",
                  value: "2",
                  help: "Constant bitrate mode"
                },
                %{
                  flags: "E..V.......",
                  name: "vbr_minqp",
                  value: "8388609",
                  help: "Variable bitrate mode with MinQP (deprecated)"
                },
                %{
                  flags: "E..V.......",
                  name: "ll_2pass_quality",
                  value: "8388609",
                  help: "Multi-pass optimized for image quality (deprecated)"
                },
                %{
                  flags: "E..V.......",
                  name: "ll_2pass_size",
                  value: "8388610",
                  help: "Multi-pass optimized for constant frame size (deprecated)"
                },
                %{
                  flags: "E..V.......",
                  name: "vbr_2pass",
                  value: "8388609",
                  help: "Multi-pass variable bitrate mode (deprecated)"
                },
                %{
                  flags: "E..V.......",
                  name: "cbr_ld_hq",
                  value: "8388610",
                  help: "Constant bitrate low delay high quality mode"
                },
                %{
                  flags: "E..V.......",
                  name: "cbr_hq",
                  value: "8388610",
                  help: "Constant bitrate high quality mode"
                },
                %{
                  flags: "E..V.......",
                  name: "vbr_hq",
                  value: "8388609",
                  help: "Variable bitrate high quality mode"
                }
              ],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "rc-lookahead",
              type: :int,
              help:
                "Number of frames to look ahead for rate-control (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "surfaces",
              type: :int,
              help: "Number of concurrent surfaces (from 0 to 64) (default 0)",
              ranges: [%{max: "64", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "cbr",
              type: :boolean,
              help: "Use cbr encoding mode (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "2pass",
              type: :boolean,
              help: "Use 2pass encoding mode (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            },
            %{
              flags: "E..V.......",
              name: "gpu",
              type: :int,
              help:
                "Selects which NVENC capable GPU to use. First GPU is 0, second is 1, and so on. (from -2 to INT_MAX) (default any)",
              ranges: [%{max: "INT_MAX", min: "-2"}],
              constants: [
                %{
                  flags: "E..V.......",
                  name: "any",
                  value: "-1",
                  help: "Pick the first device available"
                },
                %{
                  flags: "E..V.......",
                  name: "list",
                  value: "-2",
                  help: "List the available devices"
                }
              ],
              declared_default: "any"
            },
            %{
              flags: "E..V.......",
              name: "rgb_mode",
              type: :int,
              help:
                "Configure how nvenc handles packed RGB input. (from 0 to INT_MAX) (default yuv420)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [
                %{
                  flags: "E..V.......",
                  name: "yuv420",
                  value: "1",
                  help: "Convert to yuv420"
                },
                %{
                  flags: "E..V.......",
                  name: "yuv444",
                  value: "2",
                  help: "Convert to yuv444"
                },
                %{
                  flags: "E..V.......",
                  name: "disabled",
                  value: "0",
                  help: "Disables support, throws an error."
                }
              ],
              declared_default: "yuv420"
            },
            %{
              flags: "E..V.......",
              name: "delay",
              type: :int,
              help:
                "Delay frame output by the given amount of frames (from 0 to INT_MAX) (default INT_MAX)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "INT_MAX"
            },
            %{
              flags: "E..V.......",
              name: "no-scenecut",
              type: :boolean,
              help:
                "When lookahead is enabled, set this to 1 to disable adaptive I-frame insertion at scene cuts (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "forced-idr",
              type: :boolean,
              help: "If forcing keyframes, force them as IDR frames. (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "b_adapt",
              type: :boolean,
              help:
                "When lookahead is enabled, set this to 0 to disable adaptive B-frame decision (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            },
            %{
              flags: "E..V.......",
              name: "spatial-aq",
              type: :boolean,
              help: "set to 1 to enable Spatial AQ (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "spatial_aq",
              type: :boolean,
              help: "set to 1 to enable Spatial AQ (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "temporal-aq",
              type: :boolean,
              help: "set to 1 to enable Temporal AQ (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "temporal_aq",
              type: :boolean,
              help: "set to 1 to enable Temporal AQ (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "zerolatency",
              type: :boolean,
              help:
                "Set 1 to indicate zero latency operation (no reordering delay) (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "nonref_p",
              type: :boolean,
              help:
                "Set this to 1 to enable automatic insertion of non-reference P-frames (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "strict_gop",
              type: :boolean,
              help: "Set 1 to minimize GOP-to-GOP rate fluctuations (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "aq-strength",
              type: :int,
              help:
                "When Spatial AQ is enabled, this field is used to specify AQ strength. AQ strength scale is from 1 (low) - 15 (aggressive) (from 1 to 15) (default 8)",
              ranges: [%{max: "15", min: "1"}],
              constants: [],
              declared_default: "8"
            },
            %{
              flags: "E..V.......",
              name: "cq",
              type: :float,
              help:
                "Set target quality level (0 to 51, 0 means automatic) for constant quality mode in VBR rate control (from 0 to 51) (default 0)",
              ranges: [%{max: "51", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "aud",
              type: :boolean,
              help: "Use access unit delimiters (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "bluray-compat",
              type: :boolean,
              help: "Bluray compatibility workarounds (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "init_qpP",
              type: :int,
              help: "Initial QP value for P frame (from -1 to 51) (default -1)",
              ranges: [%{max: "51", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "init_qpB",
              type: :int,
              help: "Initial QP value for B frame (from -1 to 51) (default -1)",
              ranges: [%{max: "51", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "init_qpI",
              type: :int,
              help: "Initial QP value for I frame (from -1 to 51) (default -1)",
              ranges: [%{max: "51", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "qp",
              type: :int,
              help:
                "Constant quantization parameter rate control method (from -1 to 51) (default -1)",
              ranges: [%{max: "51", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "qp_cb_offset",
              type: :int,
              help: "Quantization parameter offset for cb channel (from -12 to 12) (default 0)",
              ranges: [%{max: "12", min: "-12"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "qp_cr_offset",
              type: :int,
              help: "Quantization parameter offset for cr channel (from -12 to 12) (default 0)",
              ranges: [%{max: "12", min: "-12"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "weighted_pred",
              type: :int,
              help: "Set 1 to enable weighted prediction (from 0 to 1) (default 0)",
              ranges: [%{max: "1", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "coder",
              type: :int,
              help: "Coder type (from -1 to 2) (default default)",
              ranges: [%{max: "2", min: "-1"}],
              constants: [
                %{flags: "E..V.......", name: "default", value: "-1", help: ""},
                %{flags: "E..V.......", name: "auto", value: "0", help: ""},
                %{flags: "E..V.......", name: "cabac", value: "1", help: ""},
                %{flags: "E..V.......", name: "cavlc", value: "2", help: ""},
                %{flags: "E..V.......", name: "ac", value: "1", help: ""},
                %{flags: "E..V.......", name: "vlc", value: "2", help: ""}
              ],
              declared_default: "default"
            },
            %{
              flags: "E..V.......",
              name: "b_ref_mode",
              type: :int,
              help: "Use B frames as references (from -1 to 2) (default -1)",
              ranges: [%{max: "2", min: "-1"}],
              constants: [
                %{
                  flags: "E..V.......",
                  name: "disabled",
                  value: "0",
                  help: "B frames will not be used for reference"
                },
                %{
                  flags: "E..V.......",
                  name: "each",
                  value: "1",
                  help: "Each B frame will be used for reference"
                },
                %{
                  flags: "E..V.......",
                  name: "middle",
                  value: "2",
                  help: "Only (number of B frames)/2 will be used for reference"
                }
              ],
              declared_default: "-1"
            },
            %{
              flags: "E..V.......",
              name: "a53cc",
              type: :boolean,
              help: "Use A53 Closed Captions (if available) (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            },
            %{
              flags: "E..V.......",
              name: "dpb_size",
              type: :int,
              help:
                "Specifies the DPB size used for encoding (0 means automatic) (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "multipass",
              type: :int,
              help: "Set the multipass encoding (from 0 to 2) (default disabled)",
              ranges: [%{max: "2", min: "0"}],
              constants: [
                %{
                  flags: "E..V.......",
                  name: "disabled",
                  value: "0",
                  help: "Single Pass"
                },
                %{
                  flags: "E..V.......",
                  name: "qres",
                  value: "1",
                  help: "Two Pass encoding is enabled where first Pass is quarter resolution"
                },
                %{
                  flags: "E..V.......",
                  name: "fullres",
                  value: "2",
                  help: "Two Pass encoding is enabled where first Pass is full resolution"
                }
              ],
              declared_default: "disabled"
            },
            %{
              flags: "E..V.......",
              name: "ldkfs",
              type: :int,
              help:
                "Low delay key frame scale; Specifies the Scene Change frame size increase allowed in case of single frame VBV and CBR (from 0 to 255) (default 0)",
              ranges: [%{max: "255", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "extra_sei",
              type: :boolean,
              help:
                "Pass on extra SEI data (e.g. a53 cc) to be included in the bitstream (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            },
            %{
              flags: "E..V.......",
              name: "udu_sei",
              type: :boolean,
              help: "Pass on user data unregistered SEI if available (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "intra-refresh",
              type: :boolean,
              help: "Use Periodic Intra Refresh instead of IDR frames (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "single-slice-intra-refresh",
              type: :boolean,
              help: "Use single slice intra refresh (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "max_slice_size",
              type: :int,
              help: "Maximum encoded slice size in bytes (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "constrained-encoding",
              type: :boolean,
              help:
                "Enable constrainedFrame encoding where each slice in the constrained picture is independent of other slices (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "lookahead_level",
              type: :int,
              help:
                "Specifies the lookahead level. Higher level may improve quality at the expense of performance. (from -1 to 15) (default -1)",
              ranges: [%{max: "15", min: "-1"}],
              constants: [
                %{flags: "E..V.......", name: "auto", value: "15", help: ""},
                %{flags: "E..V.......", name: "0", value: "0", help: ""},
                %{flags: "E..V.......", name: "1", value: "1", help: ""},
                %{flags: "E..V.......", name: "2", value: "2", help: ""},
                %{flags: "E..V.......", name: "3", value: "3", help: ""}
              ],
              declared_default: "-1"
            }
          ]
        }
      ]
    },
    %{
      description: "AAC (Advanced Audio Coding)",
      names: ["aac"],
      kind: :encoder,
      media_type: :audio,
      notes: [],
      properties: [
        {"General capabilities", "dr1 delay small "},
        {"Threading capabilities", "none"},
        {"Supported sample rates",
         "96000 88200 64000 48000 44100 32000 24000 22050 16000 12000 11025 8000 7350"},
        {"Supported sample formats", "fltp"}
      ],
      option_sections: [
        %{
          name: "AAC encoder",
          options: [
            %{
              flags: "E...A......",
              name: "aac_coder",
              type: :int,
              help: "Coding algorithm (from 0 to 2) (default twoloop)",
              ranges: [%{max: "2", min: "0"}],
              constants: [
                %{
                  flags: "E...A......",
                  name: "anmr",
                  value: "0",
                  help: "ANMR method"
                },
                %{
                  flags: "E...A......",
                  name: "twoloop",
                  value: "1",
                  help: "Two loop searching method"
                },
                %{
                  flags: "E...A......",
                  name: "fast",
                  value: "2",
                  help: "Fast search"
                }
              ],
              declared_default: "twoloop"
            },
            %{
              flags: "E...A......",
              name: "aac_ms",
              type: :boolean,
              help: "Force M/S stereo coding (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            },
            %{
              flags: "E...A......",
              name: "aac_is",
              type: :boolean,
              help: "Intensity stereo coding (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            },
            %{
              flags: "E...A......",
              name: "aac_pns",
              type: :boolean,
              help: "Perceptual noise substitution (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            },
            %{
              flags: "E...A......",
              name: "aac_tns",
              type: :boolean,
              help: "Temporal noise shaping (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            },
            %{
              flags: "E...A......",
              name: "aac_ltp",
              type: :boolean,
              help: "Long term prediction (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E...A......",
              name: "aac_pred",
              type: :boolean,
              help: "AAC-Main prediction (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E...A......",
              name: "aac_pce",
              type: :boolean,
              help: "Forces the use of PCEs (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            }
          ]
        }
      ]
    },
    %{
      description: "libopus Opus",
      names: ["libopus"],
      kind: :encoder,
      media_type: :audio,
      notes: [],
      properties: [
        {"General capabilities", "dr1 delay small "},
        {"Threading capabilities", "none"},
        {"Supported sample rates", "48000 24000 16000 12000 8000"},
        {"Supported sample formats", "s16 flt"}
      ],
      option_sections: [
        %{
          name: "libopus",
          options: [
            %{
              flags: "E...A......",
              name: "application",
              type: :int,
              help: "Intended application type (from 2048 to 2051) (default audio)",
              ranges: [%{max: "2051", min: "2048"}],
              constants: [
                %{
                  flags: "E...A......",
                  name: "voip",
                  value: "2048",
                  help: "Favor improved speech intelligibility"
                },
                %{
                  flags: "E...A......",
                  name: "audio",
                  value: "2049",
                  help: "Favor faithfulness to the input"
                },
                %{
                  flags: "E...A......",
                  name: "lowdelay",
                  value: "2051",
                  help: "Restrict to only the lowest delay modes, disable voice-optimized modes"
                }
              ],
              declared_default: "audio"
            },
            %{
              flags: "E...A......",
              name: "frame_duration",
              type: :float,
              help: "Duration of a frame in milliseconds (from 2.5 to 120) (default 20)",
              ranges: [%{max: "120", min: "2.5"}],
              constants: [],
              declared_default: "20"
            },
            %{
              flags: "E...A......",
              name: "packet_loss",
              type: :int,
              help: "Expected packet loss percentage (from 0 to 100) (default 0)",
              ranges: [%{max: "100", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E...A......",
              name: "fec",
              type: :boolean,
              help: "Enable inband FEC. Expected packet loss must be non-zero (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E...A......",
              name: "vbr",
              type: :int,
              help: "Variable bit rate mode (from 0 to 2) (default on)",
              ranges: [%{max: "2", min: "0"}],
              constants: [
                %{
                  flags: "E...A......",
                  name: "off",
                  value: "0",
                  help: "Use constant bit rate"
                },
                %{
                  flags: "E...A......",
                  name: "on",
                  value: "1",
                  help: "Use variable bit rate"
                },
                %{
                  flags: "E...A......",
                  name: "constrained",
                  value: "2",
                  help: "Use constrained VBR"
                }
              ],
              declared_default: "on"
            },
            %{
              flags: "E...A......",
              name: "mapping_family",
              type: :int,
              help: "Channel Mapping Family (from -1 to 255) (default -1)",
              ranges: [%{max: "255", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E...A......",
              name: "apply_phase_inv",
              type: :boolean,
              help: "Apply intensity stereo phase inversion (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            }
          ]
        }
      ]
    },
    %{
      description: "MPEG-4 part 2",
      names: ["mpeg4"],
      kind: :encoder,
      media_type: :video,
      notes: [],
      properties: [
        {"General capabilities", "delay threads "},
        {"Threading capabilities", "slice"},
        {"Supported pixel formats", "yuv420p"}
      ],
      option_sections: [
        %{
          name: "MPEG4 encoder",
          options: [
            %{
              flags: "E..V.......",
              name: "data_partitioning",
              type: :boolean,
              help: "Use data partitioning. (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "alternate_scan",
              type: :boolean,
              help: "Enable alternate scantable. (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..V.......",
              name: "mpeg_quant",
              type: :int,
              help: "Use MPEG quantizers instead of H.263 (from 0 to 1) (default 0)",
              ranges: [%{max: "1", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "b_strategy",
              type: :int,
              help: "Strategy to choose between I/P/B-frames (from 0 to 2) (default 0)",
              ranges: [%{max: "2", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "b_sensitivity",
              type: :int,
              help: "Adjust sensitivity of b_frame_strategy 1 (from 1 to INT_MAX) (default 40)",
              ranges: [%{max: "INT_MAX", min: "1"}],
              constants: [],
              declared_default: "40"
            },
            %{
              flags: "E..V.......",
              name: "brd_scale",
              type: :int,
              help: "Downscale frames for dynamic B-frame decision (from 0 to 3) (default 0)",
              ranges: [%{max: "3", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "mpv_flags",
              type: :flags,
              help: "Flags common for all mpegvideo-based encoders. (default 0)",
              ranges: [],
              constants: [
                %{
                  flags: "E..V.......",
                  name: "skip_rd",
                  value: nil,
                  help: "RD optimal MB level residual skipping"
                },
                %{
                  flags: "E..V.......",
                  name: "strict_gop",
                  value: nil,
                  help: "Strictly enforce gop size"
                },
                %{
                  flags: "E..V.......",
                  name: "qp_rd",
                  value: nil,
                  help: "Use rate distortion optimization for qp selection"
                },
                %{
                  flags: "E..V.......",
                  name: "cbp_rd",
                  value: nil,
                  help: "use rate distortion optimization for CBP"
                },
                %{
                  flags: "E..V.......",
                  name: "naq",
                  value: nil,
                  help: "normalize adaptive quantization"
                },
                %{
                  flags: "E..V.......",
                  name: "mv0",
                  value: nil,
                  help: "always try a mb with mv=<0,0>"
                }
              ],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "luma_elim_threshold",
              type: :int,
              help:
                "single coefficient elimination threshold for luminance (negative values also consider dc coefficient) (from INT_MIN to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "chroma_elim_threshold",
              type: :int,
              help:
                "single coefficient elimination threshold for chrominance (negative values also consider dc coefficient) (from INT_MIN to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "quantizer_noise_shaping",
              type: :int,
              help: "(from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "error_rate",
              type: :int,
              help:
                "Simulate errors in the bitstream to test error concealment. (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "qsquish",
              type: :float,
              help:
                "how to keep quantizer between qmin and qmax (0 = clip, 1 = use differentiable function) (from 0 to 99) (default 0)",
              ranges: [%{max: "99", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "rc_qmod_amp",
              type: :float,
              help: "experimental quantizer modulation (from -FLT_MAX to FLT_MAX) (default 0)",
              ranges: [%{max: "FLT_MAX", min: "-FLT_MAX"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "rc_qmod_freq",
              type: :int,
              help: "experimental quantizer modulation (from INT_MIN to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "rc_eq",
              type: :string,
              help:
                "Set rate control equation. When computing the expression, besides the standard functions defined in the section 'Expression Evaluation', the following functions are available: bits2qp(bits), qp2bits(qp). Also the following constants are available: iTex pTex tex mv fCode iCount mcVar var isI isP isB avgQP qComp avgIITex avgPITex avgPPTex avgBPTex avgTex.",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..V.......",
              name: "rc_init_cplx",
              type: :float,
              help:
                "initial complexity for 1-pass encoding (from -FLT_MAX to FLT_MAX) (default 0)",
              ranges: [%{max: "FLT_MAX", min: "-FLT_MAX"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "rc_buf_aggressivity",
              type: :float,
              help: "currently useless (from -FLT_MAX to FLT_MAX) (default 1)",
              ranges: [%{max: "FLT_MAX", min: "-FLT_MAX"}],
              constants: [],
              declared_default: "1"
            },
            %{
              flags: "E..V.......",
              name: "border_mask",
              type: :float,
              help:
                "increase the quantizer for macroblocks close to borders (from -FLT_MAX to FLT_MAX) (default 0)",
              ranges: [%{max: "FLT_MAX", min: "-FLT_MAX"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "lmin",
              type: :int,
              help: "minimum Lagrange factor (VBR) (from 0 to INT_MAX) (default 236)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "236"
            },
            %{
              flags: "E..V.......",
              name: "lmax",
              type: :int,
              help: "maximum Lagrange factor (VBR) (from 0 to INT_MAX) (default 3658)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "3658"
            },
            %{
              flags: "E..V.......",
              name: "skip_threshold",
              type: :int,
              help: "Frame skip threshold (from INT_MIN to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "skip_factor",
              type: :int,
              help: "Frame skip factor (from INT_MIN to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "skip_exp",
              type: :int,
              help: "Frame skip exponent (from INT_MIN to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "skip_cmp",
              type: :int,
              help: "Frame skip compare function (from INT_MIN to INT_MAX) (default dctmax)",
              ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
              constants: [
                %{
                  flags: "E..V.......",
                  name: "sad",
                  value: "0",
                  help: "Sum of absolute differences, fast"
                },
                %{
                  flags: "E..V.......",
                  name: "sse",
                  value: "1",
                  help: "Sum of squared errors"
                },
                %{
                  flags: "E..V.......",
                  name: "satd",
                  value: "2",
                  help: "Sum of absolute Hadamard transformed differences"
                },
                %{
                  flags: "E..V.......",
                  name: "dct",
                  value: "3",
                  help: "Sum of absolute DCT transformed differences"
                },
                %{
                  flags: "E..V.......",
                  name: "psnr",
                  value: "4",
                  help: "Sum of squared quantization errors, low quality"
                },
                %{
                  flags: "E..V.......",
                  name: "bit",
                  value: "5",
                  help: "Number of bits needed for the block"
                },
                %{
                  flags: "E..V.......",
                  name: "rd",
                  value: "6",
                  help: "Rate distortion optimal, slow"
                },
                %{flags: "E..V.......", name: "zero", value: "7", help: "Zero"},
                %{
                  flags: "E..V.......",
                  name: "vsad",
                  value: "8",
                  help: "Sum of absolute vertical differences"
                },
                %{
                  flags: "E..V.......",
                  name: "vsse",
                  value: "9",
                  help: "Sum of squared vertical differences"
                },
                %{
                  flags: "E..V.......",
                  name: "nsse",
                  value: "10",
                  help: "Noise preserving sum of squared differences"
                },
                %{flags: "E..V.......", name: "dct264", value: "14", help: ""},
                %{flags: "E..V.......", name: "dctmax", value: "13", help: ""},
                %{flags: "E..V.......", name: "chroma", value: "256", help: ""},
                %{
                  flags: "E..V.......",
                  name: "msad",
                  value: "15",
                  help: "Sum of absolute differences, median predicted"
                }
              ],
              declared_default: "dctmax"
            },
            %{
              flags: "E..V.......",
              name: "sc_threshold",
              type: :int,
              help: "Scene change threshold (from INT_MIN to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "noise_reduction",
              type: :int,
              help: "Noise reduction (from INT_MIN to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "ps",
              type: :int,
              help: "RTP payload size in bytes (from INT_MIN to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "motion_est",
              type: :int,
              help: "motion estimation algorithm (from 0 to 2) (default epzs)",
              ranges: [%{max: "2", min: "0"}],
              constants: [
                %{flags: "E..V.......", name: "zero", value: "0", help: ""},
                %{flags: "E..V.......", name: "epzs", value: "1", help: ""},
                %{flags: "E..V.......", name: "xone", value: "2", help: ""}
              ],
              declared_default: "epzs"
            },
            %{
              flags: "E..V.......",
              name: "mepc",
              type: :int,
              help:
                "Motion estimation bitrate penalty compensation (1.0 = 256) (from INT_MIN to INT_MAX) (default 256)",
              ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
              constants: [],
              declared_default: "256"
            },
            %{
              flags: "E..V.......",
              name: "mepre",
              type: :int,
              help: "pre motion estimation (from INT_MIN to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "intra_penalty",
              type: :int,
              help:
                "Penalty for intra blocks in block decision (from 0 to 1.07374e+09) (default 0)",
              ranges: [%{max: "1.07374e+09", min: "0"}],
              constants: [],
              declared_default: "0"
            }
          ]
        }
      ]
    },
    %{
      description: "PCM signed 16-bit little-endian",
      names: ["pcm_s16le"],
      kind: :encoder,
      media_type: :audio,
      notes: [],
      properties: [
        {"General capabilities", "dr1 variable "},
        {"Threading capabilities", "none"},
        {"Supported sample formats", "s16"}
      ],
      option_sections: []
    },
    %{
      description: "FFmpeg video codec #1",
      names: ["ffv1"],
      kind: :encoder,
      media_type: :video,
      notes: [],
      properties: [
        {"General capabilities", "dr1 delay threads "},
        {"Threading capabilities", "slice"},
        {"Supported pixel formats",
         "yuv420p yuva420p yuva422p yuv444p yuva444p yuv440p yuv422p yuv411p yuv410p bgr0 bgra yuv420p16le yuv422p16le yuv444p16le yuv444p9le yuv422p9le yuv420p9le yuv420p10le yuv422p10le yuv444p10le yuv420p12le yuv422p12le yuv444p12le yuva444p16le yuva422p16le yuva420p16le yuva444p12le yuva422p12le yuva444p10le yuva422p10le yuva420p10le yuva444p9le yuva422p9le yuva420p9le gray16le gray gbrp9le gbrp10le gbrp12le gbrp14le gbrap14le gbrap10le gbrap12le ya8 gray10le gray12le gray14le gbrp16le rgb48le gbrap16le rgba64le gray9le yuv420p14le yuv422p14le yuv444p14le yuv440p10le yuv440p12le"}
      ],
      option_sections: [
        %{
          name: "ffv1 encoder",
          options: [
            %{
              flags: "E..V.......",
              name: "slicecrc",
              type: :boolean,
              help: "Protect slices with CRCs (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            },
            %{
              flags: "E..V.......",
              name: "coder",
              type: :int,
              help: "Coder type (from -2 to 2) (default rice)",
              ranges: [%{max: "2", min: "-2"}],
              constants: [
                %{
                  flags: "E..V.......",
                  name: "rice",
                  value: "0",
                  help: "Golomb rice"
                },
                %{
                  flags: "E..V.......",
                  name: "range_def",
                  value: "-2",
                  help: "Range with default table"
                },
                %{
                  flags: "E..V.......",
                  name: "range_tab",
                  value: "2",
                  help: "Range with custom table"
                },
                %{
                  flags: "E..V.......",
                  name: "ac",
                  value: "1",
                  help:
                    "Range with custom table (the ac option exists for compatibility and is deprecated)"
                }
              ],
              declared_default: "rice"
            },
            %{
              flags: "E..V.......",
              name: "context",
              type: :int,
              help: "Context model (from 0 to 1) (default 0)",
              ranges: [%{max: "1", min: "0"}],
              constants: [],
              declared_default: "0"
            }
          ]
        }
      ]
    },
    %{
      description: "PNG (Portable Network Graphics) image",
      names: ["png"],
      kind: :encoder,
      media_type: :video,
      notes: [],
      properties: [
        {"General capabilities", "dr1 threads "},
        {"Threading capabilities", "frame"},
        {"Supported pixel formats",
         "rgb24 rgba rgb48be rgba64be pal8 gray ya8 gray16be ya16be monob"}
      ],
      option_sections: [
        %{
          name: "(A)PNG encoder",
          options: [
            %{
              flags: "E..V.......",
              name: "dpi",
              type: :int,
              help: "Set image resolution (in dots per inch) (from 0 to 65536) (default 0)",
              ranges: [%{max: "65536", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "dpm",
              type: :int,
              help: "Set image resolution (in dots per meter) (from 0 to 65536) (default 0)",
              ranges: [%{max: "65536", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..V.......",
              name: "pred",
              type: :int,
              help: "Prediction method (from 0 to 5) (default none)",
              ranges: [%{max: "5", min: "0"}],
              constants: [
                %{flags: "E..V.......", name: "none", value: "0", help: ""},
                %{flags: "E..V.......", name: "sub", value: "1", help: ""},
                %{flags: "E..V.......", name: "up", value: "2", help: ""},
                %{flags: "E..V.......", name: "avg", value: "3", help: ""},
                %{flags: "E..V.......", name: "paeth", value: "4", help: ""},
                %{flags: "E..V.......", name: "mixed", value: "5", help: ""}
              ],
              declared_default: "none"
            }
          ]
        }
      ]
    },
    %{
      description: "H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10",
      names: ["h264"],
      kind: :decoder,
      media_type: :video,
      notes: [],
      properties: [
        {"General capabilities", "dr1 delay threads "},
        {"Threading capabilities", "frame and slice"},
        {"Supported hardware devices", "cuda vaapi vdpau vulkan "}
      ],
      option_sections: [
        %{
          name: "H264 Decoder",
          options: [
            %{
              flags: ".D.V..X....",
              name: "is_avc",
              type: :boolean,
              help: "is avc (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: ".D.V..X....",
              name: "nal_length_size",
              type: :int,
              help: "nal_length_size (from 0 to 4) (default 0)",
              ranges: [%{max: "4", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: ".D.V.......",
              name: "enable_er",
              type: :boolean,
              help: "Enable error resilience on damaged frames (unsafe) (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            },
            %{
              flags: ".D.V.......",
              name: "x264_build",
              type: :int,
              help:
                "Assume this x264 version if no x264 version found in any SEI (from -1 to INT_MAX) (default -1)",
              ranges: [%{max: "INT_MAX", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: ".D.V.......",
              name: "skip_gray",
              type: :boolean,
              help: "Do not return gray gap frames (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: ".D.V.......",
              name: "noref_gray",
              type: :boolean,
              help: "Avoid using gray gap frames as references (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            }
          ]
        }
      ]
    },
    %{
      description: "HEVC (High Efficiency Video Coding)",
      names: ["hevc"],
      kind: :decoder,
      media_type: :video,
      notes: [],
      properties: [
        {"General capabilities", "dr1 delay threads "},
        {"Threading capabilities", "frame and slice"},
        {"Supported hardware devices", "cuda vaapi vdpau vulkan "}
      ],
      option_sections: [
        %{
          name: "HEVC decoder",
          options: [
            %{
              flags: ".D.V.......",
              name: "apply_defdispwin",
              type: :boolean,
              help: "Apply default display window from VUI (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: ".D.V.......",
              name: "strict-displaywin",
              type: :boolean,
              help: "stricly apply default display window size (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: ".D.V.......",
              name: "view_ids",
              type: {:array, :int},
              help:
                "Array of view IDs that should be decoded and output; a single -1 to decode all views",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: ".D.V..XR...",
              name: "view_ids_available",
              type: {:array, :unsigned},
              help: "Array of available view IDs is exported here",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: ".D.V..XR...",
              name: "view_pos_available",
              type: {:array, :unsigned},
              help:
                "Array of view positions for view_ids_available is exported here, as AVStereo3DView",
              ranges: [],
              constants: [],
              declared_default: nil
            }
          ]
        }
      ]
    },
    %{
      description: "AAC (Advanced Audio Coding)",
      names: ["aac"],
      kind: :decoder,
      media_type: :audio,
      notes: [],
      properties: [
        {"General capabilities", "dr1 chconf "},
        {"Threading capabilities", "none"},
        {"Supported sample formats", "fltp"},
        {"Supported channel layouts",
         "mono stereo 3.0 4.0 5.0 5.1 7.1(wide) 6.1(back) 7.1 22.2 5.1.2"}
      ],
      option_sections: [
        %{
          name: "AAC decoder",
          options: [
            %{
              flags: ".D..A......",
              name: "dual_mono_mode",
              type: :int,
              help: "Select the channel to decode for dual mono (from -1 to 2) (default auto)",
              ranges: [%{max: "2", min: "-1"}],
              constants: [
                %{
                  flags: ".D..A......",
                  name: "auto",
                  value: "-1",
                  help: "autoselection"
                },
                %{
                  flags: ".D..A......",
                  name: "main",
                  value: "1",
                  help: "Select Main/Left channel"
                },
                %{
                  flags: ".D..A......",
                  name: "sub",
                  value: "2",
                  help: "Select Sub/Right channel"
                },
                %{
                  flags: ".D..A......",
                  name: "both",
                  value: "0",
                  help: "Select both channels"
                }
              ],
              declared_default: "auto"
            },
            %{
              flags: ".D..A......",
              name: "channel_order",
              type: :int,
              help:
                "Order in which the channels are to be exported (from 0 to 1) (default default)",
              ranges: [%{max: "1", min: "0"}],
              constants: [
                %{
                  flags: ".D..A......",
                  name: "default",
                  value: "0",
                  help: "normal libavcodec channel order"
                },
                %{
                  flags: ".D..A......",
                  name: "coded",
                  value: "1",
                  help: "order in which the channels are coded in the bitstream"
                }
              ],
              declared_default: "default"
            }
          ]
        }
      ]
    },
    %{
      description: "ATSC A/52A (AC-3)",
      names: ["ac3"],
      kind: :decoder,
      media_type: :audio,
      notes: [],
      properties: [
        {"General capabilities", "dr1 chconf "},
        {"Threading capabilities", "none"},
        {"Supported sample formats", "fltp"}
      ],
      option_sections: [
        %{
          name: "(E-)AC3 decoder",
          options: [
            %{
              flags: ".D..A......",
              name: "cons_noisegen",
              type: :boolean,
              help: "enable consistent noise generation (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: ".D..A......",
              name: "drc_scale",
              type: :float,
              help: "percentage of dynamic range compression to apply (from 0 to 6) (default 1)",
              ranges: [%{max: "6", min: "0"}],
              constants: [],
              declared_default: "1"
            },
            %{
              flags: ".D..A......",
              name: "heavy_compr",
              type: :boolean,
              help: "enable heavy dynamic range compression (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: ".D..A......",
              name: "target_level",
              type: :int,
              help: "target level in -dBFS (0 not applied) (from -31 to 0) (default 0)",
              ranges: [%{max: "0", min: "-31"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: ".D..A......",
              name: "downmix",
              type: :channel_layout,
              help: "Request a specific channel layout from the decoder",
              ranges: [],
              constants: [],
              declared_default: nil
            }
          ]
        }
      ]
    },
    %{
      description: "MPEG-4 part 2",
      names: ["mpeg4"],
      kind: :decoder,
      media_type: :video,
      notes: [],
      properties: [
        {"General capabilities", "horizband dr1 delay threads "},
        {"Threading capabilities", "frame"},
        {"Supported hardware devices", "cuda vaapi vdpau "}
      ],
      option_sections: [%{name: "MPEG4 Video Decoder", options: []}]
    },
    %{
      description: "raw video",
      names: ["rawvideo"],
      kind: :decoder,
      media_type: :video,
      notes: [],
      properties: [
        {"General capabilities", "paramchange "},
        {"Threading capabilities", "none"}
      ],
      option_sections: [
        %{
          name: "rawdec",
          options: [
            %{
              flags: ".D.V.......",
              name: "top",
              type: :boolean,
              help: "top field first (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            }
          ]
        }
      ]
    },
    %{
      description: "PCM signed 16-bit little-endian",
      names: ["pcm_s16le"],
      kind: :decoder,
      media_type: :audio,
      notes: [],
      properties: [
        {"General capabilities", "dr1 paramchange "},
        {"Threading capabilities", "none"},
        {"Supported sample formats", "s16"}
      ],
      option_sections: []
    },
    %{
      description: "MP4 (MPEG-4 Part 14)",
      names: ["mp4"],
      kind: :muxer,
      media_type: nil,
      notes: [],
      properties: [
        {"Common extensions", "mp4."},
        {"Mime type", "video/mp4."},
        {"Default video codec", "h264."},
        {"Default audio codec", "aac."}
      ],
      option_sections: [
        %{
          name: "mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer",
          options: [
            %{
              flags: "E..........",
              name: "brand",
              type: :string,
              help: "Override major brand",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "empty_hdlr_name",
              type: :boolean,
              help:
                "write zero-length name string in hdlr atoms within mdia and minf atoms (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "encryption_key",
              type: :binary,
              help: "The media encryption key (hex)",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "encryption_kid",
              type: :binary,
              help: "The media encryption key identifier (hex)",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "encryption_scheme",
              type: :string,
              help: "Configures the encryption scheme, allowed values are none, cenc-aes-ctr",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "frag_duration",
              type: :int,
              help: "Maximum fragment duration (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "frag_interleave",
              type: :int,
              help:
                "Interleave samples within fragments (max number of consecutive samples, lower is tighter interleaving, but with more overhead) (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "frag_size",
              type: :int,
              help: "Maximum fragment size (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "fragment_index",
              type: :int,
              help: "Fragment number of the next fragment (from 1 to INT_MAX) (default 1)",
              ranges: [%{max: "INT_MAX", min: "1"}],
              constants: [],
              declared_default: "1"
            },
            %{
              flags: "E..........",
              name: "iods_audio_profile",
              type: :int,
              help: "iods audio profile atom. (from -1 to 255) (default -1)",
              ranges: [%{max: "255", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..........",
              name: "iods_video_profile",
              type: :int,
              help: "iods video profile atom. (from -1 to 255) (default -1)",
              ranges: [%{max: "255", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..........",
              name: "ism_lookahead",
              type: :int,
              help: "Number of lookahead entries for ISM files (from 0 to 255) (default 0)",
              ranges: [%{max: "255", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "movflags",
              type: :flags,
              help: "MOV muxer flags (default 0)",
              ranges: [],
              constants: [
                %{
                  flags: "E..........",
                  name: "cmaf",
                  value: nil,
                  help: "Write CMAF compatible fragmented MP4"
                },
                %{
                  flags: "E..........",
                  name: "dash",
                  value: nil,
                  help: "Write DASH compatible fragmented MP4"
                },
                %{
                  flags: "E..........",
                  name: "default_base_moof",
                  value: nil,
                  help: "Set the default-base-is-moof flag in tfhd atoms"
                },
                %{
                  flags: "E..........",
                  name: "delay_moov",
                  value: nil,
                  help:
                    "Delay writing the initial moov until the first fragment is cut, or until the first fragment flush"
                },
                %{
                  flags: "E..........",
                  name: "disable_chpl",
                  value: nil,
                  help: "Disable Nero chapter atom"
                },
                %{
                  flags: "E..........",
                  name: "empty_moov",
                  value: nil,
                  help: "Make the initial moov atom empty"
                },
                %{
                  flags: "E..........",
                  name: "faststart",
                  value: nil,
                  help:
                    "Run a second pass to put the index (moov atom) at the beginning of the file"
                },
                %{
                  flags: "E..........",
                  name: "frag_custom",
                  value: nil,
                  help: "Flush fragments on caller requests"
                },
                %{
                  flags: "E..........",
                  name: "frag_discont",
                  value: nil,
                  help: "Signal that the next fragment is discontinuous from earlier ones"
                },
                %{
                  flags: "E..........",
                  name: "frag_every_frame",
                  value: nil,
                  help: "Fragment at every frame"
                },
                %{
                  flags: "E..........",
                  name: "frag_keyframe",
                  value: nil,
                  help: "Fragment at video keyframes"
                },
                %{
                  flags: "E..........",
                  name: "global_sidx",
                  value: nil,
                  help: "Write a global sidx index at the start of the file"
                },
                %{
                  flags: "E..........",
                  name: "isml",
                  value: nil,
                  help: "Create a live smooth streaming feed (for pushing to a publishing point)"
                },
                %{
                  flags: "E..........",
                  name: "negative_cts_offsets",
                  value: nil,
                  help: "Use negative CTS offsets (reducing the need for edit lists)"
                },
                %{
                  flags: "E..........",
                  name: "omit_tfhd_offset",
                  value: nil,
                  help: "Omit the base data offset in tfhd atoms"
                },
                %{
                  flags: "E..........",
                  name: "prefer_icc",
                  value: nil,
                  help:
                    "If writing colr atom prioritise usage of ICC profile if it exists in stream packet side data"
                },
                %{
                  flags: "E..........",
                  name: "rtphint",
                  value: nil,
                  help: "Add RTP hint tracks"
                },
                %{
                  flags: "E..........",
                  name: "separate_moof",
                  value: nil,
                  help: "Write separate moof/mdat atoms for each track"
                },
                %{
                  flags: "E..........",
                  name: "skip_sidx",
                  value: nil,
                  help: "Skip writing of sidx atom"
                },
                %{
                  flags: "E..........",
                  name: "skip_trailer",
                  value: nil,
                  help: "Skip writing the mfra/tfra/mfro trailer for fragmented files"
                },
                %{
                  flags: "E..........",
                  name: "use_metadata_tags",
                  value: nil,
                  help: "Use mdta atom for metadata."
                },
                %{
                  flags: "E..........",
                  name: "write_colr",
                  value: nil,
                  help:
                    "Write colr atom even if the color info is unspecified (Experimental, may be renamed or changed, do not use from scripts)"
                },
                %{
                  flags: "E..........",
                  name: "write_gama",
                  value: nil,
                  help: "Write deprecated gama atom"
                },
                %{
                  flags: "E..........",
                  name: "hybrid_fragmented",
                  value: nil,
                  help:
                    "For recoverability, write a fragmented file that is converted to non-fragmented at the end."
                }
              ],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "moov_size",
              type: :int,
              help:
                "maximum moov size so it can be placed at the begin (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "min_frag_duration",
              type: :int,
              help: "Minimum fragment duration (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "mov_gamma",
              type: :float,
              help: "gamma value for gama atom (from 0 to 10) (default 0)",
              ranges: [%{max: "10", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "movie_timescale",
              type: :int,
              help: "set movie timescale (from 1 to INT_MAX) (default 1000)",
              ranges: [%{max: "INT_MAX", min: "1"}],
              constants: [],
              declared_default: "1000"
            },
            %{
              flags: "E..........",
              name: "rtpflags",
              type: :flags,
              help: "RTP muxer flags (default 0)",
              ranges: [],
              constants: [
                %{
                  flags: "E..........",
                  name: "latm",
                  value: nil,
                  help: "Use MP4A-LATM packetization instead of MPEG4-GENERIC for AAC"
                },
                %{
                  flags: "E..........",
                  name: "rfc2190",
                  value: nil,
                  help: "Use RFC 2190 packetization instead of RFC 4629 for H.263"
                },
                %{
                  flags: "E..........",
                  name: "skip_rtcp",
                  value: nil,
                  help: "Don't send RTCP sender reports"
                },
                %{
                  flags: "E..........",
                  name: "h264_mode0",
                  value: nil,
                  help: "Use mode 0 for H.264 in RTP"
                },
                %{
                  flags: "E..........",
                  name: "send_bye",
                  value: nil,
                  help: "Send RTCP BYE packets when finishing"
                }
              ],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "skip_iods",
              type: :boolean,
              help: "Skip writing iods atom. (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            },
            %{
              flags: "E..........",
              name: "use_editlist",
              type: :boolean,
              help: "use edit list (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            },
            %{
              flags: "E..........",
              name: "use_stream_ids_as_track_ids",
              type: :boolean,
              help: "use stream ids as track ids (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "video_track_timescale",
              type: :int,
              help: "set timescale of all video tracks (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "write_btrt",
              type: :boolean,
              help: "force or disable writing btrt (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            },
            %{
              flags: "E..........",
              name: "write_prft",
              type: :int,
              help:
                "Write producer reference time box with specified time source (from 0 to 2) (default 0)",
              ranges: [%{max: "2", min: "0"}],
              constants: [
                %{flags: "E..........", name: "pts", value: "2", help: ""},
                %{flags: "E..........", name: "wallclock", value: "1", help: ""}
              ],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "write_tmcd",
              type: :boolean,
              help: "force or disable writing tmcd (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            }
          ]
        }
      ]
    },
    %{
      description: "QuickTime / MOV",
      names: ["mov"],
      kind: :muxer,
      media_type: nil,
      notes: [],
      properties: [
        {"Common extensions", "mov."},
        {"Default video codec", "h264."},
        {"Default audio codec", "aac."}
      ],
      option_sections: [
        %{
          name: "mov/mp4/tgp/psp/tg2/ipod/ismv/f4v muxer",
          options: [
            %{
              flags: "E..........",
              name: "brand",
              type: :string,
              help: "Override major brand",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "empty_hdlr_name",
              type: :boolean,
              help:
                "write zero-length name string in hdlr atoms within mdia and minf atoms (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "encryption_key",
              type: :binary,
              help: "The media encryption key (hex)",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "encryption_kid",
              type: :binary,
              help: "The media encryption key identifier (hex)",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "encryption_scheme",
              type: :string,
              help: "Configures the encryption scheme, allowed values are none, cenc-aes-ctr",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "frag_duration",
              type: :int,
              help: "Maximum fragment duration (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "frag_interleave",
              type: :int,
              help:
                "Interleave samples within fragments (max number of consecutive samples, lower is tighter interleaving, but with more overhead) (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "frag_size",
              type: :int,
              help: "Maximum fragment size (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "fragment_index",
              type: :int,
              help: "Fragment number of the next fragment (from 1 to INT_MAX) (default 1)",
              ranges: [%{max: "INT_MAX", min: "1"}],
              constants: [],
              declared_default: "1"
            },
            %{
              flags: "E..........",
              name: "iods_audio_profile",
              type: :int,
              help: "iods audio profile atom. (from -1 to 255) (default -1)",
              ranges: [%{max: "255", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..........",
              name: "iods_video_profile",
              type: :int,
              help: "iods video profile atom. (from -1 to 255) (default -1)",
              ranges: [%{max: "255", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..........",
              name: "ism_lookahead",
              type: :int,
              help: "Number of lookahead entries for ISM files (from 0 to 255) (default 0)",
              ranges: [%{max: "255", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "movflags",
              type: :flags,
              help: "MOV muxer flags (default 0)",
              ranges: [],
              constants: [
                %{
                  flags: "E..........",
                  name: "cmaf",
                  value: nil,
                  help: "Write CMAF compatible fragmented MP4"
                },
                %{
                  flags: "E..........",
                  name: "dash",
                  value: nil,
                  help: "Write DASH compatible fragmented MP4"
                },
                %{
                  flags: "E..........",
                  name: "default_base_moof",
                  value: nil,
                  help: "Set the default-base-is-moof flag in tfhd atoms"
                },
                %{
                  flags: "E..........",
                  name: "delay_moov",
                  value: nil,
                  help:
                    "Delay writing the initial moov until the first fragment is cut, or until the first fragment flush"
                },
                %{
                  flags: "E..........",
                  name: "disable_chpl",
                  value: nil,
                  help: "Disable Nero chapter atom"
                },
                %{
                  flags: "E..........",
                  name: "empty_moov",
                  value: nil,
                  help: "Make the initial moov atom empty"
                },
                %{
                  flags: "E..........",
                  name: "faststart",
                  value: nil,
                  help:
                    "Run a second pass to put the index (moov atom) at the beginning of the file"
                },
                %{
                  flags: "E..........",
                  name: "frag_custom",
                  value: nil,
                  help: "Flush fragments on caller requests"
                },
                %{
                  flags: "E..........",
                  name: "frag_discont",
                  value: nil,
                  help: "Signal that the next fragment is discontinuous from earlier ones"
                },
                %{
                  flags: "E..........",
                  name: "frag_every_frame",
                  value: nil,
                  help: "Fragment at every frame"
                },
                %{
                  flags: "E..........",
                  name: "frag_keyframe",
                  value: nil,
                  help: "Fragment at video keyframes"
                },
                %{
                  flags: "E..........",
                  name: "global_sidx",
                  value: nil,
                  help: "Write a global sidx index at the start of the file"
                },
                %{
                  flags: "E..........",
                  name: "isml",
                  value: nil,
                  help: "Create a live smooth streaming feed (for pushing to a publishing point)"
                },
                %{
                  flags: "E..........",
                  name: "negative_cts_offsets",
                  value: nil,
                  help: "Use negative CTS offsets (reducing the need for edit lists)"
                },
                %{
                  flags: "E..........",
                  name: "omit_tfhd_offset",
                  value: nil,
                  help: "Omit the base data offset in tfhd atoms"
                },
                %{
                  flags: "E..........",
                  name: "prefer_icc",
                  value: nil,
                  help:
                    "If writing colr atom prioritise usage of ICC profile if it exists in stream packet side data"
                },
                %{
                  flags: "E..........",
                  name: "rtphint",
                  value: nil,
                  help: "Add RTP hint tracks"
                },
                %{
                  flags: "E..........",
                  name: "separate_moof",
                  value: nil,
                  help: "Write separate moof/mdat atoms for each track"
                },
                %{
                  flags: "E..........",
                  name: "skip_sidx",
                  value: nil,
                  help: "Skip writing of sidx atom"
                },
                %{
                  flags: "E..........",
                  name: "skip_trailer",
                  value: nil,
                  help: "Skip writing the mfra/tfra/mfro trailer for fragmented files"
                },
                %{
                  flags: "E..........",
                  name: "use_metadata_tags",
                  value: nil,
                  help: "Use mdta atom for metadata."
                },
                %{
                  flags: "E..........",
                  name: "write_colr",
                  value: nil,
                  help:
                    "Write colr atom even if the color info is unspecified (Experimental, may be renamed or changed, do not use from scripts)"
                },
                %{
                  flags: "E..........",
                  name: "write_gama",
                  value: nil,
                  help: "Write deprecated gama atom"
                },
                %{
                  flags: "E..........",
                  name: "hybrid_fragmented",
                  value: nil,
                  help:
                    "For recoverability, write a fragmented file that is converted to non-fragmented at the end."
                }
              ],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "moov_size",
              type: :int,
              help:
                "maximum moov size so it can be placed at the begin (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "min_frag_duration",
              type: :int,
              help: "Minimum fragment duration (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "mov_gamma",
              type: :float,
              help: "gamma value for gama atom (from 0 to 10) (default 0)",
              ranges: [%{max: "10", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "movie_timescale",
              type: :int,
              help: "set movie timescale (from 1 to INT_MAX) (default 1000)",
              ranges: [%{max: "INT_MAX", min: "1"}],
              constants: [],
              declared_default: "1000"
            },
            %{
              flags: "E..........",
              name: "rtpflags",
              type: :flags,
              help: "RTP muxer flags (default 0)",
              ranges: [],
              constants: [
                %{
                  flags: "E..........",
                  name: "latm",
                  value: nil,
                  help: "Use MP4A-LATM packetization instead of MPEG4-GENERIC for AAC"
                },
                %{
                  flags: "E..........",
                  name: "rfc2190",
                  value: nil,
                  help: "Use RFC 2190 packetization instead of RFC 4629 for H.263"
                },
                %{
                  flags: "E..........",
                  name: "skip_rtcp",
                  value: nil,
                  help: "Don't send RTCP sender reports"
                },
                %{
                  flags: "E..........",
                  name: "h264_mode0",
                  value: nil,
                  help: "Use mode 0 for H.264 in RTP"
                },
                %{
                  flags: "E..........",
                  name: "send_bye",
                  value: nil,
                  help: "Send RTCP BYE packets when finishing"
                }
              ],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "skip_iods",
              type: :boolean,
              help: "Skip writing iods atom. (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            },
            %{
              flags: "E..........",
              name: "use_editlist",
              type: :boolean,
              help: "use edit list (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            },
            %{
              flags: "E..........",
              name: "use_stream_ids_as_track_ids",
              type: :boolean,
              help: "use stream ids as track ids (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "video_track_timescale",
              type: :int,
              help: "set timescale of all video tracks (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "write_btrt",
              type: :boolean,
              help: "force or disable writing btrt (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            },
            %{
              flags: "E..........",
              name: "write_prft",
              type: :int,
              help:
                "Write producer reference time box with specified time source (from 0 to 2) (default 0)",
              ranges: [%{max: "2", min: "0"}],
              constants: [
                %{flags: "E..........", name: "pts", value: "2", help: ""},
                %{flags: "E..........", name: "wallclock", value: "1", help: ""}
              ],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "write_tmcd",
              type: :boolean,
              help: "force or disable writing tmcd (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            }
          ]
        }
      ]
    },
    %{
      description: "Matroska",
      names: ["matroska"],
      kind: :muxer,
      media_type: nil,
      notes: [],
      properties: [
        {"Common extensions", "mkv."},
        {"Mime type", "video/x-matroska."},
        {"Default video codec", "h264."},
        {"Default audio codec", "vorbis."},
        {"Default subtitle codec", "ass."}
      ],
      option_sections: [
        %{
          name: "matroska/webm muxer",
          options: [
            %{
              flags: "E..........",
              name: "reserve_index_space",
              type: :int,
              help:
                "reserve a given amount of space (in bytes) at the beginning of the file for the index (cues) (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "cues_to_front",
              type: :boolean,
              help:
                "move Cues (the index) to the front by shifting data if necessary (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "cluster_size_limit",
              type: :int,
              help:
                "store at most the provided amount of bytes in a cluster (from -1 to INT_MAX) (default -1)",
              ranges: [%{max: "INT_MAX", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..........",
              name: "cluster_time_limit",
              type: :int64,
              help:
                "store at most the provided number of milliseconds in a cluster (from -1 to I64_MAX) (default -1)",
              ranges: [%{max: "I64_MAX", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..........",
              name: "dash",
              type: :boolean,
              help: "create a WebM file conforming to WebM DASH specification (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "dash_track_number",
              type: :int,
              help: "track number for the DASH stream (from 1 to INT_MAX) (default 1)",
              ranges: [%{max: "INT_MAX", min: "1"}],
              constants: [],
              declared_default: "1"
            },
            %{
              flags: "E..........",
              name: "live",
              type: :boolean,
              help: "write files assuming it is a live stream (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "allow_raw_vfw",
              type: :boolean,
              help: "allow raw VFW mode (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "flipped_raw_rgb",
              type: :boolean,
              help: "store raw RGB bitmaps in VFW mode in bottom-up mode (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "write_crc32",
              type: :boolean,
              help: "write a CRC32 element inside every Level 1 element (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            },
            %{
              flags: "E..........",
              name: "default_mode",
              type: :int,
              help:
                "control how a track's FlagDefault is inferred (from 0 to 2) (default passthrough)",
              ranges: [%{max: "2", min: "0"}],
              constants: [
                %{
                  flags: "E..........",
                  name: "infer",
                  value: "0",
                  help:
                    "for each track type, mark each track of disposition default as default; if none exists, mark the first track as default"
                },
                %{
                  flags: "E..........",
                  name: "infer_no_subs",
                  value: "1",
                  help:
                    "for each track type, mark each track of disposition default as default; for audio and video: if none exists, mark the first track as default"
                },
                %{
                  flags: "E..........",
                  name: "passthrough",
                  value: "2",
                  help: "use the disposition flag as-is"
                }
              ],
              declared_default: "passthrough"
            }
          ]
        }
      ]
    },
    %{
      description: "WebM",
      names: ["webm"],
      kind: :muxer,
      media_type: nil,
      notes: [],
      properties: [
        {"Common extensions", "webm."},
        {"Mime type", "video/webm."},
        {"Default video codec", "vp9."},
        {"Default audio codec", "opus."},
        {"Default subtitle codec", "webvtt."}
      ],
      option_sections: [
        %{
          name: "matroska/webm muxer",
          options: [
            %{
              flags: "E..........",
              name: "reserve_index_space",
              type: :int,
              help:
                "reserve a given amount of space (in bytes) at the beginning of the file for the index (cues) (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "cues_to_front",
              type: :boolean,
              help:
                "move Cues (the index) to the front by shifting data if necessary (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "cluster_size_limit",
              type: :int,
              help:
                "store at most the provided amount of bytes in a cluster (from -1 to INT_MAX) (default -1)",
              ranges: [%{max: "INT_MAX", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..........",
              name: "cluster_time_limit",
              type: :int64,
              help:
                "store at most the provided number of milliseconds in a cluster (from -1 to I64_MAX) (default -1)",
              ranges: [%{max: "I64_MAX", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..........",
              name: "dash",
              type: :boolean,
              help: "create a WebM file conforming to WebM DASH specification (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "dash_track_number",
              type: :int,
              help: "track number for the DASH stream (from 1 to INT_MAX) (default 1)",
              ranges: [%{max: "INT_MAX", min: "1"}],
              constants: [],
              declared_default: "1"
            },
            %{
              flags: "E..........",
              name: "live",
              type: :boolean,
              help: "write files assuming it is a live stream (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "allow_raw_vfw",
              type: :boolean,
              help: "allow raw VFW mode (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "flipped_raw_rgb",
              type: :boolean,
              help: "store raw RGB bitmaps in VFW mode in bottom-up mode (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "write_crc32",
              type: :boolean,
              help: "write a CRC32 element inside every Level 1 element (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            },
            %{
              flags: "E..........",
              name: "default_mode",
              type: :int,
              help:
                "control how a track's FlagDefault is inferred (from 0 to 2) (default passthrough)",
              ranges: [%{max: "2", min: "0"}],
              constants: [
                %{
                  flags: "E..........",
                  name: "infer",
                  value: "0",
                  help:
                    "for each track type, mark each track of disposition default as default; if none exists, mark the first track as default"
                },
                %{
                  flags: "E..........",
                  name: "infer_no_subs",
                  value: "1",
                  help:
                    "for each track type, mark each track of disposition default as default; for audio and video: if none exists, mark the first track as default"
                },
                %{
                  flags: "E..........",
                  name: "passthrough",
                  value: "2",
                  help: "use the disposition flag as-is"
                }
              ],
              declared_default: "passthrough"
            }
          ]
        }
      ]
    },
    %{
      description: "Apple HTTP Live Streaming",
      names: ["hls"],
      kind: :muxer,
      media_type: nil,
      notes: [],
      properties: [
        {"Common extensions", "m3u8."},
        {"Default video codec", "h264."},
        {"Default audio codec", "aac."},
        {"Default subtitle codec", "webvtt."}
      ],
      option_sections: [
        %{
          name: "hls muxer",
          options: [
            %{
              flags: "E..........",
              name: "start_number",
              type: :int64,
              help: "set first number in the sequence (from 0 to I64_MAX) (default 0)",
              ranges: [%{max: "I64_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "hls_time",
              type: :duration,
              help: "set segment length (default 2)",
              ranges: [],
              constants: [],
              declared_default: "2"
            },
            %{
              flags: "E..........",
              name: "hls_init_time",
              type: :duration,
              help: "set segment length at init list (default 0)",
              ranges: [],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "hls_list_size",
              type: :int,
              help: "set maximum number of playlist entries (from 0 to INT_MAX) (default 5)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "5"
            },
            %{
              flags: "E..........",
              name: "hls_delete_threshold",
              type: :int,
              help:
                "set number of unreferenced segments to keep before deleting (from 1 to INT_MAX) (default 1)",
              ranges: [%{max: "INT_MAX", min: "1"}],
              constants: [],
              declared_default: "1"
            },
            %{
              flags: "E..........",
              name: "hls_vtt_options",
              type: :string,
              help: "set hls vtt list of options for the container format used for hls",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "hls_allow_cache",
              type: :int,
              help:
                "explicitly set whether the client MAY (1) or MUST NOT (0) cache media segments (from INT_MIN to INT_MAX) (default -1)",
              ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..........",
              name: "hls_base_url",
              type: :string,
              help: "url to prepend to each playlist entry",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "hls_segment_filename",
              type: :string,
              help: "filename template for segment files",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "hls_segment_options",
              type: :dictionary,
              help: "set segments files format options of hls",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "hls_segment_size",
              type: :int,
              help: "maximum size per segment file, (in bytes) (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "hls_key_info_file",
              type: :string,
              help: "file with key URI and key file path",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "hls_enc",
              type: :boolean,
              help: "enable AES128 encryption support (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "hls_enc_key",
              type: :string,
              help: "hex-coded 16 byte key to encrypt the segments",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "hls_enc_key_url",
              type: :string,
              help: "url to access the key to decrypt the segments",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "hls_enc_iv",
              type: :string,
              help: "hex-coded 16 byte initialization vector",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "hls_subtitle_path",
              type: :string,
              help: "set path of hls subtitles",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "hls_segment_type",
              type: :int,
              help: "set hls segment files type (from 0 to 1) (default mpegts)",
              ranges: [%{max: "1", min: "0"}],
              constants: [
                %{
                  flags: "E..........",
                  name: "mpegts",
                  value: "0",
                  help: "make segment file to mpegts files in m3u8"
                },
                %{
                  flags: "E..........",
                  name: "fmp4",
                  value: "1",
                  help: "make segment file to fragment mp4 files in m3u8"
                }
              ],
              declared_default: "mpegts"
            },
            %{
              flags: "E..........",
              name: "hls_fmp4_init_filename",
              type: :string,
              help: "set fragment mp4 file init filename (default \"init.mp4\")",
              ranges: [],
              constants: [],
              declared_default: "\"init.mp4\""
            },
            %{
              flags: "E..........",
              name: "hls_fmp4_init_resend",
              type: :boolean,
              help: "resend fragment mp4 init file after refresh m3u8 every time (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "hls_flags",
              type: :flags,
              help: "set flags affecting HLS playlist and media file generation (default 0)",
              ranges: [],
              constants: [
                %{
                  flags: "E..........",
                  name: "single_file",
                  value: nil,
                  help: "generate a single media file indexed with byte ranges"
                },
                %{
                  flags: "E..........",
                  name: "temp_file",
                  value: nil,
                  help: "write segment and playlist to temporary file and rename when complete"
                },
                %{
                  flags: "E..........",
                  name: "delete_segments",
                  value: nil,
                  help: "delete segment files that are no longer part of the playlist"
                },
                %{
                  flags: "E..........",
                  name: "round_durations",
                  value: nil,
                  help: "round durations in m3u8 to whole numbers"
                },
                %{
                  flags: "E..........",
                  name: "discont_start",
                  value: nil,
                  help: "start the playlist with a discontinuity tag"
                },
                %{
                  flags: "E..........",
                  name: "omit_endlist",
                  value: nil,
                  help: "Do not append an endlist when ending stream"
                },
                %{
                  flags: "E..........",
                  name: "split_by_time",
                  value: nil,
                  help: "split the hls segment by time which user set by hls_time"
                },
                %{
                  flags: "E..........",
                  name: "append_list",
                  value: nil,
                  help: "append the new segments into old hls segment list"
                },
                %{
                  flags: "E..........",
                  name: "program_date_time",
                  value: nil,
                  help: "add EXT-X-PROGRAM-DATE-TIME"
                },
                %{
                  flags: "E..........",
                  name: "second_level_segment_index",
                  value: nil,
                  help: "include segment index in segment filenames when use_localtime"
                },
                %{
                  flags: "E..........",
                  name: "second_level_segment_duration",
                  value: nil,
                  help: "include segment duration in segment filenames when use_localtime"
                },
                %{
                  flags: "E..........",
                  name: "second_level_segment_size",
                  value: nil,
                  help: "include segment size in segment filenames when use_localtime"
                },
                %{
                  flags: "E..........",
                  name: "periodic_rekey",
                  value: nil,
                  help: "reload keyinfo file periodically for re-keying"
                },
                %{
                  flags: "E..........",
                  name: "independent_segments",
                  value: nil,
                  help: "add EXT-X-INDEPENDENT-SEGMENTS, whenever applicable"
                },
                %{
                  flags: "E..........",
                  name: "iframes_only",
                  value: nil,
                  help: "add EXT-X-I-FRAMES-ONLY, whenever applicable"
                }
              ],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "strftime",
              type: :boolean,
              help: "set filename expansion with strftime at segment creation (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "strftime_mkdir",
              type: :boolean,
              help:
                "create last directory component in strftime-generated filename (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "hls_playlist_type",
              type: :int,
              help: "set the HLS playlist type (from 0 to 2) (default 0)",
              ranges: [%{max: "2", min: "0"}],
              constants: [
                %{
                  flags: "E..........",
                  name: "event",
                  value: "1",
                  help: "EVENT playlist"
                },
                %{
                  flags: "E..........",
                  name: "vod",
                  value: "2",
                  help: "VOD playlist"
                }
              ],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "method",
              type: :string,
              help: "set the HTTP method(default: PUT)",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "hls_start_number_source",
              type: :int,
              help: "set source of first number in sequence (from 0 to 3) (default generic)",
              ranges: [%{max: "3", min: "0"}],
              constants: [
                %{
                  flags: "E..........",
                  name: "generic",
                  value: "0",
                  help: "start_number value (default)"
                },
                %{
                  flags: "E..........",
                  name: "epoch",
                  value: "1",
                  help: "seconds since epoch"
                },
                %{
                  flags: "E..........",
                  name: "epoch_us",
                  value: "3",
                  help: "microseconds since epoch"
                },
                %{
                  flags: "E..........",
                  name: "datetime",
                  value: "2",
                  help: "current datetime as YYYYMMDDhhmmss"
                }
              ],
              declared_default: "generic"
            },
            %{
              flags: "E..........",
              name: "http_user_agent",
              type: :string,
              help: "override User-Agent field in HTTP header",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "var_stream_map",
              type: :string,
              help: "Variant stream map string",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "cc_stream_map",
              type: :string,
              help: "Closed captions stream map string",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "master_pl_name",
              type: :string,
              help: "Create HLS master playlist with this name",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "master_pl_publish_rate",
              type: :int,
              help:
                "Publish master play list every after this many segment intervals (from 0 to UINT32_MAX) (default 0)",
              ranges: [%{max: "UINT32_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "http_persistent",
              type: :boolean,
              help: "Use persistent HTTP connections (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "timeout",
              type: :duration,
              help: "set timeout for socket I/O operations (default -0.000001)",
              ranges: [],
              constants: [],
              declared_default: "-0.000001"
            },
            %{
              flags: "E..........",
              name: "ignore_io_errors",
              type: :boolean,
              help:
                "Ignore IO errors for stable long-duration runs with network output (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "headers",
              type: :string,
              help: "set custom HTTP headers, can override built in default headers",
              ranges: [],
              constants: [],
              declared_default: nil
            }
          ]
        }
      ]
    },
    %{
      description: "MPEG-TS (MPEG-2 Transport Stream)",
      names: ["mpegts"],
      kind: :muxer,
      media_type: nil,
      notes: [],
      properties: [
        {"Common extensions", "ts,m2t,m2ts,mts."},
        {"Mime type", "video/MP2T."},
        {"Default video codec", "mpeg2video."},
        {"Default audio codec", "mp2."}
      ],
      option_sections: [
        %{
          name: "MPEGTS muxer",
          options: [
            %{
              flags: "E..........",
              name: "mpegts_transport_stream_id",
              type: :int,
              help: "Set transport_stream_id field. (from 1 to 65535) (default 1)",
              ranges: [%{max: "65535", min: "1"}],
              constants: [],
              declared_default: "1"
            },
            %{
              flags: "E..........",
              name: "mpegts_original_network_id",
              type: :int,
              help: "Set original_network_id field. (from 1 to 65535) (default 65281)",
              ranges: [%{max: "65535", min: "1"}],
              constants: [],
              declared_default: "65281"
            },
            %{
              flags: "E..........",
              name: "mpegts_service_id",
              type: :int,
              help: "Set service_id field. (from 1 to 65535) (default 1)",
              ranges: [%{max: "65535", min: "1"}],
              constants: [],
              declared_default: "1"
            },
            %{
              flags: "E..........",
              name: "mpegts_service_type",
              type: :int,
              help: "Set service_type field. (from 1 to 255) (default digital_tv)",
              ranges: [%{max: "255", min: "1"}],
              constants: [
                %{
                  flags: "E..........",
                  name: "digital_tv",
                  value: "1",
                  help: "Digital Television."
                },
                %{
                  flags: "E..........",
                  name: "digital_radio",
                  value: "2",
                  help: "Digital Radio."
                },
                %{
                  flags: "E..........",
                  name: "teletext",
                  value: "3",
                  help: "Teletext."
                },
                %{
                  flags: "E..........",
                  name: "advanced_codec_digital_radio",
                  value: "10",
                  help: "Advanced Codec Digital Radio."
                },
                %{
                  flags: "E..........",
                  name: "mpeg2_digital_hdtv",
                  value: "17",
                  help: "MPEG2 Digital HDTV."
                },
                %{
                  flags: "E..........",
                  name: "advanced_codec_digital_sdtv",
                  value: "22",
                  help: "Advanced Codec Digital SDTV."
                },
                %{
                  flags: "E..........",
                  name: "advanced_codec_digital_hdtv",
                  value: "25",
                  help: "Advanced Codec Digital HDTV."
                },
                %{
                  flags: "E..........",
                  name: "hevc_digital_hdtv",
                  value: "31",
                  help: "HEVC Digital Television Service."
                }
              ],
              declared_default: "digital_tv"
            },
            %{
              flags: "E..........",
              name: "mpegts_pmt_start_pid",
              type: :int,
              help: "Set the first pid of the PMT. (from 32 to 8186) (default 4096)",
              ranges: [%{max: "8186", min: "32"}],
              constants: [],
              declared_default: "4096"
            },
            %{
              flags: "E..........",
              name: "mpegts_start_pid",
              type: :int,
              help: "Set the first pid. (from 32 to 8186) (default 256)",
              ranges: [%{max: "8186", min: "32"}],
              constants: [],
              declared_default: "256"
            },
            %{
              flags: "E..........",
              name: "mpegts_m2ts_mode",
              type: :boolean,
              help: "Enable m2ts mode. (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            },
            %{
              flags: "E..........",
              name: "muxrate",
              type: :int,
              help: "(from 0 to INT_MAX) (default 1)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "1"
            },
            %{
              flags: "E..........",
              name: "pes_payload_size",
              type: :int,
              help: "Minimum PES packet payload in bytes (from 0 to INT_MAX) (default 2930)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "2930"
            },
            %{
              flags: "E..........",
              name: "mpegts_flags",
              type: :flags,
              help: "MPEG-TS muxing flags (default 0)",
              ranges: [],
              constants: [
                %{
                  flags: "E..........",
                  name: "resend_headers",
                  value: nil,
                  help: "Reemit PAT/PMT before writing the next packet"
                },
                %{
                  flags: "E..........",
                  name: "latm",
                  value: nil,
                  help: "Use LATM packetization for AAC"
                },
                %{
                  flags: "E..........",
                  name: "pat_pmt_at_frames",
                  value: nil,
                  help: "Reemit PAT and PMT at each video frame"
                },
                %{
                  flags: "E..........",
                  name: "system_b",
                  value: nil,
                  help: "Conform to System B (DVB) instead of System A (ATSC)"
                },
                %{
                  flags: "E..........",
                  name: "initial_discontinuity",
                  value: nil,
                  help: "Mark initial packets as discontinuous"
                },
                %{
                  flags: "E..........",
                  name: "nit",
                  value: nil,
                  help: "Enable NIT transmission"
                },
                %{
                  flags: "E..........",
                  name: "omit_rai",
                  value: nil,
                  help: "Disable writing of random access indicator"
                }
              ],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "mpegts_copyts",
              type: :boolean,
              help: "don't offset dts/pts (default auto)",
              ranges: [],
              constants: [],
              declared_default: "auto"
            },
            %{
              flags: "E..........",
              name: "tables_version",
              type: :int,
              help: "set PAT, PMT, SDT and NIT version (from 0 to 31) (default 0)",
              ranges: [%{max: "31", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "omit_video_pes_length",
              type: :boolean,
              help: "Omit the PES packet length for video packets (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            },
            %{
              flags: "E..........",
              name: "pcr_period",
              type: :int,
              help: "PCR retransmission time in milliseconds (from -1 to INT_MAX) (default -1)",
              ranges: [%{max: "INT_MAX", min: "-1"}],
              constants: [],
              declared_default: "-1"
            },
            %{
              flags: "E..........",
              name: "pat_period",
              type: :duration,
              help: "PAT/PMT retransmission time limit in seconds (default 0.1)",
              ranges: [],
              constants: [],
              declared_default: "0.1"
            },
            %{
              flags: "E..........",
              name: "sdt_period",
              type: :duration,
              help: "SDT retransmission time limit in seconds (default 0.5)",
              ranges: [],
              constants: [],
              declared_default: "0.5"
            },
            %{
              flags: "E..........",
              name: "nit_period",
              type: :duration,
              help: "NIT retransmission time limit in seconds (default 0.5)",
              ranges: [],
              constants: [],
              declared_default: "0.5"
            }
          ]
        }
      ]
    },
    %{
      description: "segment",
      names: ["segment"],
      kind: :muxer,
      media_type: nil,
      notes: [],
      properties: [],
      option_sections: [
        %{
          name: "(stream) segment muxer",
          options: [
            %{
              flags: "E..........",
              name: "reference_stream",
              type: :string,
              help: "set reference stream (default \"auto\")",
              ranges: [],
              constants: [],
              declared_default: "\"auto\""
            },
            %{
              flags: "E..........",
              name: "segment_format",
              type: :string,
              help: "set container format used for the segments",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "segment_format_options",
              type: :dictionary,
              help: "set list of options for the container format used for the segments",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "segment_list",
              type: :string,
              help: "set the segment list filename",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "segment_header_filename",
              type: :string,
              help: "write a single file containing the header",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "segment_list_flags",
              type: :flags,
              help: "set flags affecting segment list generation (default cache)",
              ranges: [],
              constants: [
                %{
                  flags: "E..........",
                  name: "cache",
                  value: nil,
                  help: "allow list caching"
                },
                %{
                  flags: "E..........",
                  name: "live",
                  value: nil,
                  help: "enable live-friendly list generation (useful for HLS)"
                }
              ],
              declared_default: "cache"
            },
            %{
              flags: "E..........",
              name: "segment_list_size",
              type: :int,
              help: "set the maximum number of playlist entries (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "segment_list_type",
              type: :int,
              help: "set the segment list type (from -1 to 4) (default -1)",
              ranges: [%{max: "4", min: "-1"}],
              constants: [
                %{
                  flags: "E..........",
                  name: "flat",
                  value: "0",
                  help: "flat format"
                },
                %{
                  flags: "E..........",
                  name: "csv",
                  value: "1",
                  help: "csv format"
                },
                %{
                  flags: "E..........",
                  name: "ext",
                  value: "3",
                  help: "extended format"
                },
                %{
                  flags: "E..........",
                  name: "ffconcat",
                  value: "4",
                  help: "ffconcat format"
                },
                %{
                  flags: "E..........",
                  name: "m3u8",
                  value: "2",
                  help: "M3U8 format"
                },
                %{
                  flags: "E..........",
                  name: "hls",
                  value: "2",
                  help: "Apple HTTP Live Streaming compatible"
                }
              ],
              declared_default: "-1"
            },
            %{
              flags: "E..........",
              name: "segment_atclocktime",
              type: :boolean,
              help: "set segment to be cut at clocktime (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "segment_clocktime_offset",
              type: :duration,
              help: "set segment clocktime offset (default 0)",
              ranges: [],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "segment_clocktime_wrap_duration",
              type: :duration,
              help: "set segment clocktime wrapping duration (default INT64_MAX)",
              ranges: [],
              constants: [],
              declared_default: "INT64_MAX"
            },
            %{
              flags: "E..........",
              name: "segment_time",
              type: :duration,
              help: "set segment duration (default 2)",
              ranges: [],
              constants: [],
              declared_default: "2"
            },
            %{
              flags: "E..........",
              name: "segment_time_delta",
              type: :duration,
              help: "set approximation value used for the segment times (default 0)",
              ranges: [],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "min_seg_duration",
              type: :duration,
              help: "set minimum segment duration (default 0)",
              ranges: [],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "segment_times",
              type: :string,
              help: "set segment split time points",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "segment_frames",
              type: :string,
              help: "set segment split frame numbers",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "segment_wrap",
              type: :int,
              help: "set number after which the index wraps (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "segment_list_entry_prefix",
              type: :string,
              help: "set base url prefix for segments",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: "E..........",
              name: "segment_start_number",
              type: :int,
              help:
                "set the sequence number of the first segment (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "segment_wrap_number",
              type: :int,
              help:
                "set the number of wrap before the first segment (from 0 to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "strftime",
              type: :boolean,
              help: "set filename expansion with strftime at segment creation (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "increment_tc",
              type: :boolean,
              help: "increment timecode between each segment (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "break_non_keyframes",
              type: :boolean,
              help: "allow breaking segments on non-keyframes (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "individual_header_trailer",
              type: :boolean,
              help: "write header/trailer to each segment (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            },
            %{
              flags: "E..........",
              name: "write_header_trailer",
              type: :boolean,
              help:
                "write a header to the first segment and a trailer to the last one (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            },
            %{
              flags: "E..........",
              name: "reset_timestamps",
              type: :boolean,
              help: "reset timestamps at the beginning of each segment (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "initial_offset",
              type: :duration,
              help: "set initial timestamp offset (default 0)",
              ranges: [],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: "E..........",
              name: "write_empty_segments",
              type: :boolean,
              help: "allow writing empty 'filler' segments (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            }
          ]
        }
      ]
    },
    %{
      description: "Multiple muxer tee",
      names: ["tee"],
      kind: :muxer,
      media_type: nil,
      notes: [],
      properties: [],
      option_sections: [
        %{
          name: "Tee muxer",
          options: [
            %{
              flags: "E..........",
              name: "use_fifo",
              type: :boolean,
              help:
                "Use fifo pseudo-muxer to separate actual muxers from encoder (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "fifo_options",
              type: :dictionary,
              help: "fifo pseudo-muxer options",
              ranges: [],
              constants: [],
              declared_default: nil
            }
          ]
        }
      ]
    },
    %{
      description: "raw null video",
      names: ["null"],
      kind: :muxer,
      media_type: nil,
      notes: [],
      properties: [
        {"Default video codec", "wrapped_avframe."},
        {"Default audio codec", "pcm_s16le."}
      ],
      option_sections: []
    },
    %{
      description: "image2 sequence",
      names: ["image2"],
      kind: :muxer,
      media_type: nil,
      notes: [],
      properties: [
        {"Common extensions",
         "bmp,dpx,exr,jls,jpeg,jpg,jxl,ljpg,pam,pbm,pcx,pfm,pgm,pgmyuv,phm,png,ppm,sgi,tga,tif,tiff,jp2,j2c,j2k,xwd,sun,ras,rs,im1,im8,im24,sunras,vbn,xbm,xface,pix,y,avif,qoi,hdr,wbmp."},
        {"Default video codec", "mjpeg."}
      ],
      option_sections: [
        %{
          name: "image2 muxer",
          options: [
            %{
              flags: "E..........",
              name: "update",
              type: :boolean,
              help: "continuously overwrite one file (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "start_number",
              type: :int,
              help: "set first number in the sequence (from 0 to INT_MAX) (default 1)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "1"
            },
            %{
              flags: "E..........",
              name: "strftime",
              type: :boolean,
              help: "use strftime for filename (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "frame_pts",
              type: :boolean,
              help: "use current frame pts for filename (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "atomic_writing",
              type: :boolean,
              help: "write files atomically (using temporary files and renames) (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: "E..........",
              name: "protocol_opts",
              type: :dictionary,
              help: "specify protocol options for the opened files",
              ranges: [],
              constants: [],
              declared_default: nil
            }
          ]
        }
      ]
    },
    %{
      description: "QuickTime / MOV",
      names: ["mov", "mp4", "m4a", "3gp", "3g2", "mj2"],
      kind: :demuxer,
      media_type: nil,
      notes: [],
      properties: [
        {"Common extensions", "mov,mp4,m4a,3gp,3g2,mj2,psp,m4b,ism,ismv,isma,f4v,avif,heic,heif."}
      ],
      option_sections: [
        %{
          name: "mov,mp4,m4a,3gp,3g2,mj2",
          options: [
            %{
              flags: ".D.V.......",
              name: "use_absolute_path",
              type: :boolean,
              help:
                "allow using absolute path when opening alias, this is a possible security issue (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: ".D.V.......",
              name: "seek_streams_individually",
              type: :boolean,
              help: "Seek each stream individually to the closest point (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            },
            %{
              flags: ".D.V.......",
              name: "ignore_editlist",
              type: :boolean,
              help: "Ignore the edit list atom. (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: ".D.V.......",
              name: "advanced_editlist",
              type: :boolean,
              help:
                "Modify the AVIndex according to the editlists. Use this option to decode in the order specified by the edits. (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            },
            %{
              flags: ".D.V.......",
              name: "ignore_chapters",
              type: :boolean,
              help: "(default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: ".D.V.......",
              name: "use_mfra_for",
              type: :int,
              help: "use mfra for fragment timestamps (from -1 to 2) (default auto)",
              ranges: [%{max: "2", min: "-1"}],
              constants: [
                %{flags: ".D.V.......", name: "auto", value: "-1", help: "auto"},
                %{flags: ".D.V.......", name: "dts", value: "1", help: "dts"},
                %{flags: ".D.V.......", name: "pts", value: "2", help: "pts"}
              ],
              declared_default: "auto"
            },
            %{
              flags: ".D.V.......",
              name: "use_tfdt",
              type: :boolean,
              help: "use tfdt for fragment timestamps (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            },
            %{
              flags: ".D.V.......",
              name: "export_all",
              type: :boolean,
              help: "Export unrecognized metadata entries (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: ".D.V.......",
              name: "export_xmp",
              type: :boolean,
              help: "Export full XMP metadata (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: ".D.........",
              name: "activation_bytes",
              type: :binary,
              help: "Secret bytes for Audible AAX files",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: ".D.........",
              name: "audible_key",
              type: :binary,
              help: "AES-128 Key for Audible AAXC files",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: ".D.........",
              name: "audible_iv",
              type: :binary,
              help: "AES-128 IV for Audible AAXC files",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: ".D.........",
              name: "audible_fixed_key",
              type: :binary,
              help: "Fixed key used for handling Audible AAX files",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: ".D.........",
              name: "decryption_key",
              type: :binary,
              help: "The media decryption key (hex)",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: ".D.V.......",
              name: "enable_drefs",
              type: :boolean,
              help: "Enable external track support. (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: ".D.........",
              name: "max_stts_delta",
              type: :int,
              help:
                "treat offsets above this value as invalid (from 0 to UINT32_MAX) (default 4294487295)",
              ranges: [%{max: "UINT32_MAX", min: "0"}],
              constants: [],
              declared_default: "4294487295"
            },
            %{
              flags: ".D.........",
              name: "interleaved_read",
              type: :boolean,
              help: "Interleave packets from multiple tracks at demuxer level (default true)",
              ranges: [],
              constants: [],
              declared_default: "true"
            }
          ]
        }
      ]
    },
    %{
      description: "Matroska / WebM",
      names: ["matroska", "webm"],
      kind: :demuxer,
      media_type: nil,
      notes: [],
      properties: [{"Common extensions", "mkv,mk3d,mka,mks,webm."}],
      option_sections: []
    },
    %{
      description: "raw video",
      names: ["rawvideo"],
      kind: :demuxer,
      media_type: nil,
      notes: [],
      properties: [{"Common extensions", "yuv,cif,qcif,rgb."}],
      option_sections: [
        %{
          name: "rawvideo demuxer",
          options: [
            %{
              flags: ".D.........",
              name: "pixel_format",
              type: :string,
              help: "set pixel format (default \"yuv420p\")",
              ranges: [],
              constants: [],
              declared_default: "\"yuv420p\""
            },
            %{
              flags: ".D.........",
              name: "video_size",
              type: :image_size,
              help: "set frame size",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: ".D.........",
              name: "framerate",
              type: :video_rate,
              help: "set frame rate (default \"25\")",
              ranges: [],
              constants: [],
              declared_default: "\"25\""
            }
          ]
        }
      ]
    },
    %{
      description: "PCM signed 16-bit little-endian",
      names: ["s16le"],
      kind: :demuxer,
      media_type: nil,
      notes: [],
      properties: [{"Common extensions", "sw."}],
      option_sections: [
        %{
          name: "pcm demuxer",
          options: [
            %{
              flags: ".D.........",
              name: "sample_rate",
              type: :int,
              help: "(from 0 to INT_MAX) (default 44100)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [],
              declared_default: "44100"
            },
            %{
              flags: ".D.........",
              name: "ch_layout",
              type: :channel_layout,
              help: "(default \"mono\")",
              ranges: [],
              constants: [],
              declared_default: "\"mono\""
            }
          ]
        }
      ]
    },
    %{
      description: "Libavfilter virtual input device",
      names: ["lavfi"],
      kind: :demuxer,
      media_type: nil,
      notes: [],
      properties: [],
      option_sections: [
        %{
          name: "lavfi indev",
          options: [
            %{
              flags: ".D.........",
              name: "graph",
              type: :string,
              help: "set libavfilter graph",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: ".D.........",
              name: "graph_file",
              type: :string,
              help: "set libavfilter graph filename",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: ".D.........",
              name: "dumpgraph",
              type: :string,
              help: "dump graph to stderr",
              ranges: [],
              constants: [],
              declared_default: nil
            }
          ]
        }
      ]
    },
    %{
      description: "MP2/3 (MPEG audio layer 2/3)",
      names: ["mp3"],
      kind: :demuxer,
      media_type: nil,
      notes: [],
      properties: [{"Common extensions", "mp2,mp3,m2a,mpa."}],
      option_sections: [
        %{
          name: "mp3",
          options: [
            %{
              flags: ".D.........",
              name: "usetoc",
              type: :boolean,
              help: "use table of contents (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            }
          ]
        }
      ]
    },
    %{
      description: "image2 sequence",
      names: ["image2"],
      kind: :demuxer,
      media_type: nil,
      notes: [],
      properties: [],
      option_sections: [
        %{
          name: "image2 demuxer",
          options: [
            %{
              flags: ".D.........",
              name: "pattern_type",
              type: :int,
              help: "set pattern type (from 0 to INT_MAX) (default 4)",
              ranges: [%{max: "INT_MAX", min: "0"}],
              constants: [
                %{
                  flags: ".D.........",
                  name: "glob_sequence",
                  value: "0",
                  help: "select glob/sequence pattern type"
                },
                %{
                  flags: ".D.........",
                  name: "glob",
                  value: "1",
                  help: "select glob pattern type"
                },
                %{
                  flags: ".D.........",
                  name: "sequence",
                  value: "2",
                  help: "select sequence pattern type"
                },
                %{
                  flags: ".D.........",
                  name: "none",
                  value: "3",
                  help: "disable pattern matching"
                }
              ],
              declared_default: "4"
            },
            %{
              flags: ".D.........",
              name: "start_number",
              type: :int,
              help: "set first number in the sequence (from INT_MIN to INT_MAX) (default 0)",
              ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
              constants: [],
              declared_default: "0"
            },
            %{
              flags: ".D.........",
              name: "start_number_range",
              type: :int,
              help:
                "set range for looking at the first sequence number (from 1 to INT_MAX) (default 5)",
              ranges: [%{max: "INT_MAX", min: "1"}],
              constants: [],
              declared_default: "5"
            },
            %{
              flags: ".D.........",
              name: "ts_from_file",
              type: :int,
              help: "set frame timestamp from file's one (from 0 to 2) (default none)",
              ranges: [%{max: "2", min: "0"}],
              constants: [
                %{flags: ".D.........", name: "none", value: "0", help: "none"},
                %{
                  flags: ".D.........",
                  name: "sec",
                  value: "1",
                  help: "second precision"
                },
                %{
                  flags: ".D.........",
                  name: "ns",
                  value: "2",
                  help: "nano second precision"
                }
              ],
              declared_default: "none"
            },
            %{
              flags: ".D.........",
              name: "export_path_metadata",
              type: :boolean,
              help: "enable metadata containing input path information (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            },
            %{
              flags: ".D.........",
              name: "framerate",
              type: :video_rate,
              help: "set the video framerate (default \"25\")",
              ranges: [],
              constants: [],
              declared_default: "\"25\""
            },
            %{
              flags: ".D.........",
              name: "pixel_format",
              type: :string,
              help: "set video pixel format",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: ".D.........",
              name: "video_size",
              type: :image_size,
              help: "set video size",
              ranges: [],
              constants: [],
              declared_default: nil
            },
            %{
              flags: ".D.........",
              name: "loop",
              type: :boolean,
              help: "force loop over input file sequence (default false)",
              ranges: [],
              constants: [],
              declared_default: "false"
            }
          ]
        }
      ]
    }
  ],
  shared: [
    %{
      name: "AVCodecContext",
      options: [
        %{
          flags: "E..VA......",
          name: "b",
          type: :int64,
          help: "set bitrate (in bits/s) (from 0 to I64_MAX) (default 200000)",
          ranges: [%{max: "I64_MAX", min: "0"}],
          constants: [],
          declared_default: "200000"
        },
        %{
          flags: "E...A......",
          name: "ab",
          type: :int64,
          help: "set bitrate (in bits/s) (from 0 to INT_MAX) (default 128000)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [],
          declared_default: "128000"
        },
        %{
          flags: "E..VA......",
          name: "bt",
          type: :int,
          help:
            "Set video bitrate tolerance (in bits/s). In 1-pass mode, bitrate tolerance specifies how far ratecontrol is willing to deviate from the target average bitrate value. This is not related to minimum/maximum bitrate. Lowering tolerance too much has an adverse effect on quality. (from 0 to INT_MAX) (default 4000000)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [],
          declared_default: "4000000"
        },
        %{
          flags: "ED.VAS.....",
          name: "flags",
          type: :flags,
          help: "(default 0)",
          ranges: [],
          constants: [
            %{
              flags: ".D.V.......",
              name: "unaligned",
              value: nil,
              help: "allow decoders to produce unaligned output"
            },
            %{
              flags: "E..V.......",
              name: "mv4",
              value: nil,
              help: "use four motion vectors per macroblock (MPEG-4)"
            },
            %{
              flags: "E..V.......",
              name: "qpel",
              value: nil,
              help: "use 1/4-pel motion compensation"
            },
            %{
              flags: "E..V.......",
              name: "loop",
              value: nil,
              help: "use loop filter"
            },
            %{
              flags: "ED.V.......",
              name: "gray",
              value: nil,
              help: "only decode/encode grayscale"
            },
            %{
              flags: "E..V.......",
              name: "psnr",
              value: nil,
              help: "error[?] variables will be set during encoding"
            },
            %{
              flags: "E..V.......",
              name: "ildct",
              value: nil,
              help: "use interlaced DCT"
            },
            %{
              flags: "ED.V.......",
              name: "low_delay",
              value: nil,
              help: "force low delay"
            },
            %{
              flags: "E..VA......",
              name: "global_header",
              value: nil,
              help: "place global headers in extradata instead of every keyframe"
            },
            %{
              flags: "ED.VAS.....",
              name: "bitexact",
              value: nil,
              help: "use only bitexact functions (except (I)DCT)"
            },
            %{
              flags: "E..V.......",
              name: "aic",
              value: nil,
              help: "H.263 advanced intra coding / MPEG-4 AC prediction"
            },
            %{
              flags: "E..V.......",
              name: "ilme",
              value: nil,
              help: "interlaced motion estimation"
            },
            %{
              flags: "E..V.......",
              name: "cgop",
              value: nil,
              help: "closed GOP"
            },
            %{
              flags: ".D.V.......",
              name: "output_corrupt",
              value: nil,
              help: "Output even potentially corrupted frames"
            },
            %{
              flags: ".D.VA.....P",
              name: "drop_changed",
              value: nil,
              help: "Drop frames whose parameters differ from first decoded frame"
            }
          ],
          declared_default: "0"
        },
        %{
          flags: "ED.VAS.....",
          name: "flags2",
          type: :flags,
          help: "(default 0)",
          ranges: [],
          constants: [
            %{
              flags: "E..V.......",
              name: "fast",
              value: nil,
              help: "allow non-spec-compliant speedup tricks"
            },
            %{
              flags: "E..V.......",
              name: "noout",
              value: nil,
              help: "skip bitstream encoding"
            },
            %{
              flags: ".D.V.......",
              name: "ignorecrop",
              value: nil,
              help: "ignore cropping information from sps"
            },
            %{
              flags: "E..V.......",
              name: "local_header",
              value: nil,
              help: "place global headers at every keyframe instead of in extradata"
            },
            %{
              flags: ".D.V.......",
              name: "chunks",
              value: nil,
              help: "Frame data might be split into multiple chunks"
            },
            %{
              flags: ".D.V.......",
              name: "showall",
              value: nil,
              help: "Show all frames before the first keyframe"
            },
            %{
              flags: ".D.V.......",
              name: "export_mvs",
              value: nil,
              help: "export motion vectors through frame side data"
            },
            %{
              flags: ".D..A......",
              name: "skip_manual",
              value: nil,
              help: "do not skip samples and export skip information as frame side data"
            },
            %{
              flags: ".D...S.....",
              name: "ass_ro_flush_noop",
              value: nil,
              help: "do not reset ASS ReadOrder field on flush"
            },
            %{
              flags: ".D...S.....",
              name: "icc_profiles",
              value: nil,
              help: "generate/parse embedded ICC profiles from/to colorimetry tags"
            }
          ],
          declared_default: "0"
        },
        %{
          flags: "ED.VAS.....",
          name: "export_side_data",
          type: :flags,
          help: "Export metadata as side data (default 0)",
          ranges: [],
          constants: [
            %{
              flags: ".D.V.......",
              name: "mvs",
              value: nil,
              help: "export motion vectors through frame side data"
            },
            %{
              flags: "E..VAS.....",
              name: "prft",
              value: nil,
              help: "export Producer Reference Time through packet side data"
            },
            %{
              flags: ".D.V.......",
              name: "venc_params",
              value: nil,
              help: "export video encoding parameters through frame side data"
            },
            %{
              flags: ".D.V.......",
              name: "film_grain",
              value: nil,
              help: "export film grain parameters through frame side data"
            },
            %{
              flags: ".D.V.......",
              name: "enhancements",
              value: nil,
              help: "export picture enhancement metadata through frame side data"
            }
          ],
          declared_default: "0"
        },
        %{
          flags: "E..V.......",
          name: "g",
          type: :int,
          help: "set the group of picture (GOP) size (from INT_MIN to INT_MAX) (default 12)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [],
          declared_default: "12"
        },
        %{
          flags: "ED..A......",
          name: "ar",
          type: :int,
          help: "set audio sampling rate (in Hz) (from 0 to INT_MAX) (default 0)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E...A......",
          name: "cutoff",
          type: :int,
          help: "set cutoff bandwidth (from INT_MIN to INT_MAX) (default 0)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E...A......",
          name: "frame_size",
          type: :int,
          help: "(from 0 to INT_MAX) (default 0)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..V.......",
          name: "qcomp",
          type: :float,
          help:
            "video quantizer scale compression (VBR). Constant of ratecontrol equation. Recommended range for default rc_eq: 0.0-1.0 (from -FLT_MAX to FLT_MAX) (default 0.5)",
          ranges: [%{max: "FLT_MAX", min: "-FLT_MAX"}],
          constants: [],
          declared_default: "0.5"
        },
        %{
          flags: "E..V.......",
          name: "qblur",
          type: :float,
          help: "video quantizer scale blur (VBR) (from -1 to FLT_MAX) (default 0.5)",
          ranges: [%{max: "FLT_MAX", min: "-1"}],
          constants: [],
          declared_default: "0.5"
        },
        %{
          flags: "E..V.......",
          name: "qmin",
          type: :int,
          help: "minimum video quantizer scale (VBR) (from -1 to 69) (default 2)",
          ranges: [%{max: "69", min: "-1"}],
          constants: [],
          declared_default: "2"
        },
        %{
          flags: "E..V.......",
          name: "qmax",
          type: :int,
          help: "maximum video quantizer scale (VBR) (from -1 to 1024) (default 31)",
          ranges: [%{max: "1024", min: "-1"}],
          constants: [],
          declared_default: "31"
        },
        %{
          flags: "E..V.......",
          name: "qdiff",
          type: :int,
          help:
            "maximum difference between the quantizer scales (VBR) (from INT_MIN to INT_MAX) (default 3)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [],
          declared_default: "3"
        },
        %{
          flags: "E..V.......",
          name: "bf",
          type: :int,
          help:
            "set maximum number of B-frames between non-B-frames (from -1 to INT_MAX) (default 0)",
          ranges: [%{max: "INT_MAX", min: "-1"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..V.......",
          name: "b_qfactor",
          type: :float,
          help: "QP factor between P- and B-frames (from -FLT_MAX to FLT_MAX) (default 1.25)",
          ranges: [%{max: "FLT_MAX", min: "-FLT_MAX"}],
          constants: [],
          declared_default: "1.25"
        },
        %{
          flags: ".D.V.......",
          name: "bug",
          type: :flags,
          help: "work around not autodetected encoder bugs (default autodetect)",
          ranges: [],
          constants: [
            %{flags: ".D.V.......", name: "autodetect", value: nil, help: ""},
            %{
              flags: ".D.V.......",
              name: "xvid_ilace",
              value: nil,
              help: "Xvid interlacing bug (autodetected if FOURCC == XVIX)"
            },
            %{
              flags: ".D.V.......",
              name: "ump4",
              value: nil,
              help: "(autodetected if FOURCC == UMP4)"
            },
            %{
              flags: ".D.V.......",
              name: "no_padding",
              value: nil,
              help: "padding bug (autodetected)"
            },
            %{flags: ".D.V.......", name: "amv", value: nil, help: ""},
            %{flags: ".D.V.......", name: "qpel_chroma", value: nil, help: ""},
            %{
              flags: ".D.V.......",
              name: "std_qpel",
              value: nil,
              help: "old standard qpel (autodetected per FOURCC/version)"
            },
            %{flags: ".D.V.......", name: "qpel_chroma2", value: nil, help: ""},
            %{
              flags: ".D.V.......",
              name: "direct_blocksize",
              value: nil,
              help: "direct-qpel-blocksize bug (autodetected per FOURCC/version)"
            },
            %{
              flags: ".D.V.......",
              name: "edge",
              value: nil,
              help: "edge padding bug (autodetected per FOURCC/version)"
            },
            %{flags: ".D.V.......", name: "hpel_chroma", value: nil, help: ""},
            %{flags: ".D.V.......", name: "dc_clip", value: nil, help: ""},
            %{
              flags: ".D.V.......",
              name: "ms",
              value: nil,
              help: "work around various bugs in Microsoft's broken decoders"
            },
            %{
              flags: ".D.V.......",
              name: "trunc",
              value: nil,
              help: "truncated frames"
            },
            %{flags: ".D.V.......", name: "iedge", value: nil, help: ""}
          ],
          declared_default: "autodetect"
        },
        %{
          flags: "ED.VA......",
          name: "strict",
          type: :int,
          help: "how strictly to follow the standards (from INT_MIN to INT_MAX) (default normal)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [
            %{
              flags: "ED.VA......",
              name: "very",
              value: "2",
              help:
                "strictly conform to a older more strict version of the spec or reference software"
            },
            %{
              flags: "ED.VA......",
              name: "strict",
              value: "1",
              help:
                "strictly conform to all the things in the spec no matter what the consequences"
            },
            %{flags: "ED.VA......", name: "normal", value: "0", help: ""},
            %{
              flags: "ED.VA......",
              name: "unofficial",
              value: "-1",
              help: "allow unofficial extensions"
            },
            %{
              flags: "ED.VA......",
              name: "experimental",
              value: "-2",
              help: "allow non-standardized experimental things"
            }
          ],
          declared_default: "normal"
        },
        %{
          flags: "E..V.......",
          name: "b_qoffset",
          type: :float,
          help: "QP offset between P- and B-frames (from -FLT_MAX to FLT_MAX) (default 1.25)",
          ranges: [%{max: "FLT_MAX", min: "-FLT_MAX"}],
          constants: [],
          declared_default: "1.25"
        },
        %{
          flags: "ED.VAS.....",
          name: "err_detect",
          type: :flags,
          help: "set error detection flags (default 0)",
          ranges: [],
          constants: [
            %{
              flags: "ED.VAS.....",
              name: "crccheck",
              value: nil,
              help: "verify embedded CRCs"
            },
            %{
              flags: "ED.VAS.....",
              name: "bitstream",
              value: nil,
              help: "detect bitstream specification deviations"
            },
            %{
              flags: "ED.VAS.....",
              name: "buffer",
              value: nil,
              help: "detect improper bitstream length"
            },
            %{
              flags: "ED.VAS.....",
              name: "explode",
              value: nil,
              help: "abort decoding on minor error detection"
            },
            %{
              flags: "ED.VAS.....",
              name: "ignore_err",
              value: nil,
              help: "ignore errors"
            },
            %{
              flags: "ED.VAS.....",
              name: "careful",
              value: nil,
              help:
                "consider things that violate the spec, are fast to check and have not been seen in the wild as errors"
            },
            %{
              flags: "ED.VAS.....",
              name: "compliant",
              value: nil,
              help: "consider all spec non compliancies as errors"
            },
            %{
              flags: "ED.VAS.....",
              name: "aggressive",
              value: nil,
              help: "consider things that a sane encoder should not do as an error"
            }
          ],
          declared_default: "0"
        },
        %{
          flags: "E..VA......",
          name: "maxrate",
          type: :int64,
          help:
            "maximum bitrate (in bits/s). Used for VBV together with bufsize. (from 0 to INT_MAX) (default 0)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..VA......",
          name: "minrate",
          type: :int64,
          help:
            "minimum bitrate (in bits/s). Most useful in setting up a CBR encode. It is of little use otherwise. (from INT_MIN to INT_MAX) (default 0)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..VA......",
          name: "bufsize",
          type: :int,
          help: "set ratecontrol buffer size (in bits) (from INT_MIN to INT_MAX) (default 0)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..V.......",
          name: "i_qfactor",
          type: :float,
          help: "QP factor between P- and I-frames (from -FLT_MAX to FLT_MAX) (default -0.8)",
          ranges: [%{max: "FLT_MAX", min: "-FLT_MAX"}],
          constants: [],
          declared_default: "-0.8"
        },
        %{
          flags: "E..V.......",
          name: "i_qoffset",
          type: :float,
          help: "QP offset between P- and I-frames (from -FLT_MAX to FLT_MAX) (default 0)",
          ranges: [%{max: "FLT_MAX", min: "-FLT_MAX"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..V.......",
          name: "dct",
          type: :int,
          help: "DCT algorithm (from 0 to INT_MAX) (default auto)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [
            %{
              flags: "E..V.......",
              name: "auto",
              value: "0",
              help: "autoselect a good one"
            },
            %{
              flags: "E..V.......",
              name: "fastint",
              value: "1",
              help: "fast integer"
            },
            %{
              flags: "E..V.......",
              name: "int",
              value: "2",
              help: "accurate integer"
            },
            %{flags: "E..V.......", name: "mmx", value: "3", help: ""},
            %{flags: "E..V.......", name: "altivec", value: "5", help: ""},
            %{
              flags: "E..V.......",
              name: "faan",
              value: "6",
              help: "floating point AAN DCT"
            },
            %{flags: "E..V.......", name: "neon", value: "7", help: ""}
          ],
          declared_default: "auto"
        },
        %{
          flags: "E..V.......",
          name: "lumi_mask",
          type: :float,
          help:
            "compresses bright areas stronger than medium ones (from -FLT_MAX to FLT_MAX) (default 0)",
          ranges: [%{max: "FLT_MAX", min: "-FLT_MAX"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..V.......",
          name: "tcplx_mask",
          type: :float,
          help: "temporal complexity masking (from -FLT_MAX to FLT_MAX) (default 0)",
          ranges: [%{max: "FLT_MAX", min: "-FLT_MAX"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..V.......",
          name: "scplx_mask",
          type: :float,
          help: "spatial complexity masking (from -FLT_MAX to FLT_MAX) (default 0)",
          ranges: [%{max: "FLT_MAX", min: "-FLT_MAX"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..V.......",
          name: "p_mask",
          type: :float,
          help: "inter masking (from -FLT_MAX to FLT_MAX) (default 0)",
          ranges: [%{max: "FLT_MAX", min: "-FLT_MAX"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..V.......",
          name: "dark_mask",
          type: :float,
          help:
            "compresses dark areas stronger than medium ones (from -FLT_MAX to FLT_MAX) (default 0)",
          ranges: [%{max: "FLT_MAX", min: "-FLT_MAX"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "ED.V.......",
          name: "idct",
          type: :int,
          help: "select IDCT implementation (from 0 to INT_MAX) (default auto)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [
            %{flags: "ED.V.......", name: "auto", value: "0", help: ""},
            %{flags: "ED.V.......", name: "int", value: "1", help: ""},
            %{flags: "ED.V.......", name: "simple", value: "2", help: ""},
            %{flags: "ED.V.......", name: "simplemmx", value: "3", help: ""},
            %{flags: "ED.V.......", name: "arm", value: "7", help: ""},
            %{flags: "ED.V.......", name: "altivec", value: "8", help: ""},
            %{flags: "ED.V.......", name: "simplearm", value: "10", help: ""},
            %{
              flags: "ED.V.......",
              name: "simplearmv5te",
              value: "16",
              help: ""
            },
            %{flags: "ED.V.......", name: "simplearmv6", value: "17", help: ""},
            %{flags: "ED.V.......", name: "simpleneon", value: "22", help: ""},
            %{flags: "ED.V.......", name: "xvid", value: "14", help: ""},
            %{
              flags: "ED.V.......",
              name: "xvidmmx",
              value: "14",
              help: "deprecated, for compatibility only"
            },
            %{
              flags: "ED.V.......",
              name: "faani",
              value: "20",
              help: "floating point AAN IDCT"
            },
            %{flags: "ED.V.......", name: "simpleauto", value: "128", help: ""}
          ],
          declared_default: "auto"
        },
        %{
          flags: ".D.V.......",
          name: "ec",
          type: :flags,
          help: "set error concealment strategy (default guess_mvs+deblock)",
          ranges: [],
          constants: [
            %{
              flags: ".D.V.......",
              name: "guess_mvs",
              value: nil,
              help: "iterative motion vector (MV) search (slow)"
            },
            %{
              flags: ".D.V.......",
              name: "deblock",
              value: nil,
              help: "use strong deblock filter for damaged MBs"
            },
            %{
              flags: ".D.V.......",
              name: "favor_inter",
              value: nil,
              help: "favor predicting from the previous frame"
            }
          ],
          declared_default: "guess_mvs+deblock"
        },
        %{
          flags: "E..V.......",
          name: "aspect",
          type: :rational,
          help: "sample aspect ratio (from 0 to 10) (default 0/1)",
          ranges: [%{max: "10", min: "0"}],
          constants: [],
          declared_default: "0/1"
        },
        %{
          flags: "E..V.......",
          name: "sar",
          type: :rational,
          help: "sample aspect ratio (from 0 to 10) (default 0/1)",
          ranges: [%{max: "10", min: "0"}],
          constants: [],
          declared_default: "0/1"
        },
        %{
          flags: "ED.VAS.....",
          name: "debug",
          type: :flags,
          help: "print specific debug info (default 0)",
          ranges: [],
          constants: [
            %{
              flags: ".D.V.......",
              name: "pict",
              value: nil,
              help: "picture info"
            },
            %{
              flags: "E..V.......",
              name: "rc",
              value: nil,
              help: "rate control"
            },
            %{flags: ".D.V.......", name: "bitstream", value: nil, help: ""},
            %{
              flags: ".D.V.......",
              name: "mb_type",
              value: nil,
              help: "macroblock (MB) type"
            },
            %{
              flags: ".D.V.......",
              name: "qp",
              value: nil,
              help: "per-block quantization parameter (QP)"
            },
            %{flags: ".D.V.......", name: "dct_coeff", value: nil, help: ""},
            %{
              flags: ".D.V.......",
              name: "green_metadata",
              value: nil,
              help: ""
            },
            %{flags: ".D.V.......", name: "skip", value: nil, help: ""},
            %{flags: ".D.V.......", name: "startcode", value: nil, help: ""},
            %{
              flags: ".D.V.......",
              name: "er",
              value: nil,
              help: "error recognition"
            },
            %{
              flags: ".D.V.......",
              name: "mmco",
              value: nil,
              help: "memory management control operations (H.264)"
            },
            %{flags: ".D.V.......", name: "bugs", value: nil, help: ""},
            %{
              flags: ".D.V.......",
              name: "buffers",
              value: nil,
              help: "picture buffer allocations"
            },
            %{
              flags: ".D.VA......",
              name: "thread_ops",
              value: nil,
              help: "threading operations"
            },
            %{
              flags: ".D.VA......",
              name: "nomc",
              value: nil,
              help: "skip motion compensation"
            }
          ],
          declared_default: "0"
        },
        %{
          flags: "E..V.......",
          name: "dia_size",
          type: :int,
          help: "diamond type & size for motion estimation (from INT_MIN to INT_MAX) (default 0)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..V.......",
          name: "last_pred",
          type: :int,
          help:
            "amount of motion predictors from the previous frame (from INT_MIN to INT_MAX) (default 0)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..V.......",
          name: "pre_dia_size",
          type: :int,
          help:
            "diamond type & size for motion estimation pre-pass (from INT_MIN to INT_MAX) (default 0)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..V.......",
          name: "subq",
          type: :int,
          help: "sub-pel motion estimation quality (from INT_MIN to INT_MAX) (default 8)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [],
          declared_default: "8"
        },
        %{
          flags: "E..V.......",
          name: "me_range",
          type: :int,
          help:
            "limit motion vectors range (1023 for DivX player) (from INT_MIN to INT_MAX) (default 0)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..VA......",
          name: "global_quality",
          type: :int,
          help: "(from INT_MIN to INT_MAX) (default 0)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..V.......",
          name: "mbd",
          type: :int,
          help:
            "macroblock decision algorithm (high quality mode) (from 0 to 2) (default simple)",
          ranges: [%{max: "2", min: "0"}],
          constants: [
            %{
              flags: "E..V.......",
              name: "simple",
              value: "0",
              help: "use mbcmp"
            },
            %{
              flags: "E..V.......",
              name: "bits",
              value: "1",
              help: "use fewest bits"
            },
            %{
              flags: "E..V.......",
              name: "rd",
              value: "2",
              help: "use best rate distortion"
            }
          ],
          declared_default: "simple"
        },
        %{
          flags: "E..V.......",
          name: "rc_init_occupancy",
          type: :int,
          help:
            "number of bits which should be loaded into the rc buffer before decoding starts (from INT_MIN to INT_MAX) (default 0)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "ED.VA......",
          name: "threads",
          type: :int,
          help: "set the number of threads (from 0 to INT_MAX) (default 1)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [
            %{
              flags: "ED.V.......",
              name: "auto",
              value: "0",
              help: "autodetect a suitable number of threads to use"
            }
          ],
          declared_default: "1"
        },
        %{
          flags: "E..V.......",
          name: "dc",
          type: :int,
          help: "intra_dc_precision (from -8 to 16) (default 0)",
          ranges: [%{max: "16", min: "-8"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..V.......",
          name: "nssew",
          type: :int,
          help: "nsse weight (from INT_MIN to INT_MAX) (default 8)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [],
          declared_default: "8"
        },
        %{
          flags: ".D.V.......",
          name: "skip_top",
          type: :int,
          help:
            "number of macroblock rows at the top which are skipped (from INT_MIN to INT_MAX) (default 0)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: ".D.V.......",
          name: "skip_bottom",
          type: :int,
          help:
            "number of macroblock rows at the bottom which are skipped (from INT_MIN to INT_MAX) (default 0)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..VA......",
          name: "profile",
          type: :int,
          help: "(from INT_MIN to INT_MAX) (default unknown)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [
            %{flags: "E..VA......", name: "unknown", value: "-99", help: ""},
            %{flags: "E..V.......", name: "main10", value: "2", help: ""}
          ],
          declared_default: "unknown"
        },
        %{
          flags: "E..VA......",
          name: "level",
          type: :int,
          help:
            "encoding level, usually corresponding to the profile level, codec-specific (from INT_MIN to INT_MAX) (default unknown)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [
            %{flags: "E..VA......", name: "unknown", value: "-99", help: ""}
          ],
          declared_default: "unknown"
        },
        %{
          flags: ".D.VA......",
          name: "lowres",
          type: :int,
          help: "decode at 1= 1/2, 2=1/4, 3=1/8 resolutions (from 0 to INT_MAX) (default 0)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..V.......",
          name: "cmp",
          type: :int,
          help: "full-pel ME compare function (from INT_MIN to INT_MAX) (default sad)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [
            %{
              flags: "E..V.......",
              name: "sad",
              value: "0",
              help: "sum of absolute differences, fast"
            },
            %{
              flags: "E..V.......",
              name: "sse",
              value: "1",
              help: "sum of squared errors"
            },
            %{
              flags: "E..V.......",
              name: "satd",
              value: "2",
              help: "sum of absolute Hadamard transformed differences"
            },
            %{
              flags: "E..V.......",
              name: "dct",
              value: "3",
              help: "sum of absolute DCT transformed differences"
            },
            %{
              flags: "E..V.......",
              name: "psnr",
              value: "4",
              help: "sum of squared quantization errors (avoid, low quality)"
            },
            %{
              flags: "E..V.......",
              name: "bit",
              value: "5",
              help: "number of bits needed for the block"
            },
            %{
              flags: "E..V.......",
              name: "rd",
              value: "6",
              help: "rate distortion optimal, slow"
            },
            %{flags: "E..V.......", name: "zero", value: "7", help: "0"},
            %{
              flags: "E..V.......",
              name: "vsad",
              value: "8",
              help: "sum of absolute vertical differences"
            },
            %{
              flags: "E..V.......",
              name: "vsse",
              value: "9",
              help: "sum of squared vertical differences"
            },
            %{
              flags: "E..V.......",
              name: "nsse",
              value: "10",
              help: "noise preserving sum of squared differences"
            },
            %{
              flags: "E..V.......",
              name: "w53",
              value: "11",
              help: "5/3 wavelet, only used in snow"
            },
            %{
              flags: "E..V.......",
              name: "w97",
              value: "12",
              help: "9/7 wavelet, only used in snow"
            },
            %{flags: "E..V.......", name: "dctmax", value: "13", help: ""},
            %{flags: "E..V.......", name: "chroma", value: "256", help: ""},
            %{
              flags: "E..V.......",
              name: "msad",
              value: "15",
              help: "sum of absolute differences, median predicted"
            }
          ],
          declared_default: "sad"
        },
        %{
          flags: "E..V.......",
          name: "subcmp",
          type: :int,
          help: "sub-pel ME compare function (from INT_MIN to INT_MAX) (default sad)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [
            %{
              flags: "E..V.......",
              name: "sad",
              value: "0",
              help: "sum of absolute differences, fast"
            },
            %{
              flags: "E..V.......",
              name: "sse",
              value: "1",
              help: "sum of squared errors"
            },
            %{
              flags: "E..V.......",
              name: "satd",
              value: "2",
              help: "sum of absolute Hadamard transformed differences"
            },
            %{
              flags: "E..V.......",
              name: "dct",
              value: "3",
              help: "sum of absolute DCT transformed differences"
            },
            %{
              flags: "E..V.......",
              name: "psnr",
              value: "4",
              help: "sum of squared quantization errors (avoid, low quality)"
            },
            %{
              flags: "E..V.......",
              name: "bit",
              value: "5",
              help: "number of bits needed for the block"
            },
            %{
              flags: "E..V.......",
              name: "rd",
              value: "6",
              help: "rate distortion optimal, slow"
            },
            %{flags: "E..V.......", name: "zero", value: "7", help: "0"},
            %{
              flags: "E..V.......",
              name: "vsad",
              value: "8",
              help: "sum of absolute vertical differences"
            },
            %{
              flags: "E..V.......",
              name: "vsse",
              value: "9",
              help: "sum of squared vertical differences"
            },
            %{
              flags: "E..V.......",
              name: "nsse",
              value: "10",
              help: "noise preserving sum of squared differences"
            },
            %{
              flags: "E..V.......",
              name: "w53",
              value: "11",
              help: "5/3 wavelet, only used in snow"
            },
            %{
              flags: "E..V.......",
              name: "w97",
              value: "12",
              help: "9/7 wavelet, only used in snow"
            },
            %{flags: "E..V.......", name: "dctmax", value: "13", help: ""},
            %{flags: "E..V.......", name: "chroma", value: "256", help: ""},
            %{
              flags: "E..V.......",
              name: "msad",
              value: "15",
              help: "sum of absolute differences, median predicted"
            }
          ],
          declared_default: "sad"
        },
        %{
          flags: "E..V.......",
          name: "mbcmp",
          type: :int,
          help: "macroblock compare function (from INT_MIN to INT_MAX) (default sad)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [
            %{
              flags: "E..V.......",
              name: "sad",
              value: "0",
              help: "sum of absolute differences, fast"
            },
            %{
              flags: "E..V.......",
              name: "sse",
              value: "1",
              help: "sum of squared errors"
            },
            %{
              flags: "E..V.......",
              name: "satd",
              value: "2",
              help: "sum of absolute Hadamard transformed differences"
            },
            %{
              flags: "E..V.......",
              name: "dct",
              value: "3",
              help: "sum of absolute DCT transformed differences"
            },
            %{
              flags: "E..V.......",
              name: "psnr",
              value: "4",
              help: "sum of squared quantization errors (avoid, low quality)"
            },
            %{
              flags: "E..V.......",
              name: "bit",
              value: "5",
              help: "number of bits needed for the block"
            },
            %{
              flags: "E..V.......",
              name: "rd",
              value: "6",
              help: "rate distortion optimal, slow"
            },
            %{flags: "E..V.......", name: "zero", value: "7", help: "0"},
            %{
              flags: "E..V.......",
              name: "vsad",
              value: "8",
              help: "sum of absolute vertical differences"
            },
            %{
              flags: "E..V.......",
              name: "vsse",
              value: "9",
              help: "sum of squared vertical differences"
            },
            %{
              flags: "E..V.......",
              name: "nsse",
              value: "10",
              help: "noise preserving sum of squared differences"
            },
            %{
              flags: "E..V.......",
              name: "w53",
              value: "11",
              help: "5/3 wavelet, only used in snow"
            },
            %{
              flags: "E..V.......",
              name: "w97",
              value: "12",
              help: "9/7 wavelet, only used in snow"
            },
            %{flags: "E..V.......", name: "dctmax", value: "13", help: ""},
            %{flags: "E..V.......", name: "chroma", value: "256", help: ""},
            %{
              flags: "E..V.......",
              name: "msad",
              value: "15",
              help: "sum of absolute differences, median predicted"
            }
          ],
          declared_default: "sad"
        },
        %{
          flags: "E..V.......",
          name: "ildctcmp",
          type: :int,
          help: "interlaced DCT compare function (from INT_MIN to INT_MAX) (default vsad)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [
            %{
              flags: "E..V.......",
              name: "sad",
              value: "0",
              help: "sum of absolute differences, fast"
            },
            %{
              flags: "E..V.......",
              name: "sse",
              value: "1",
              help: "sum of squared errors"
            },
            %{
              flags: "E..V.......",
              name: "satd",
              value: "2",
              help: "sum of absolute Hadamard transformed differences"
            },
            %{
              flags: "E..V.......",
              name: "dct",
              value: "3",
              help: "sum of absolute DCT transformed differences"
            },
            %{
              flags: "E..V.......",
              name: "psnr",
              value: "4",
              help: "sum of squared quantization errors (avoid, low quality)"
            },
            %{
              flags: "E..V.......",
              name: "bit",
              value: "5",
              help: "number of bits needed for the block"
            },
            %{
              flags: "E..V.......",
              name: "rd",
              value: "6",
              help: "rate distortion optimal, slow"
            },
            %{flags: "E..V.......", name: "zero", value: "7", help: "0"},
            %{
              flags: "E..V.......",
              name: "vsad",
              value: "8",
              help: "sum of absolute vertical differences"
            },
            %{
              flags: "E..V.......",
              name: "vsse",
              value: "9",
              help: "sum of squared vertical differences"
            },
            %{
              flags: "E..V.......",
              name: "nsse",
              value: "10",
              help: "noise preserving sum of squared differences"
            },
            %{
              flags: "E..V.......",
              name: "w53",
              value: "11",
              help: "5/3 wavelet, only used in snow"
            },
            %{
              flags: "E..V.......",
              name: "w97",
              value: "12",
              help: "9/7 wavelet, only used in snow"
            },
            %{flags: "E..V.......", name: "dctmax", value: "13", help: ""},
            %{flags: "E..V.......", name: "chroma", value: "256", help: ""},
            %{
              flags: "E..V.......",
              name: "msad",
              value: "15",
              help: "sum of absolute differences, median predicted"
            }
          ],
          declared_default: "vsad"
        },
        %{
          flags: "E..V.......",
          name: "precmp",
          type: :int,
          help: "pre motion estimation compare function (from INT_MIN to INT_MAX) (default sad)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [
            %{
              flags: "E..V.......",
              name: "sad",
              value: "0",
              help: "sum of absolute differences, fast"
            },
            %{
              flags: "E..V.......",
              name: "sse",
              value: "1",
              help: "sum of squared errors"
            },
            %{
              flags: "E..V.......",
              name: "satd",
              value: "2",
              help: "sum of absolute Hadamard transformed differences"
            },
            %{
              flags: "E..V.......",
              name: "dct",
              value: "3",
              help: "sum of absolute DCT transformed differences"
            },
            %{
              flags: "E..V.......",
              name: "psnr",
              value: "4",
              help: "sum of squared quantization errors (avoid, low quality)"
            },
            %{
              flags: "E..V.......",
              name: "bit",
              value: "5",
              help: "number of bits needed for the block"
            },
            %{
              flags: "E..V.......",
              name: "rd",
              value: "6",
              help: "rate distortion optimal, slow"
            },
            %{flags: "E..V.......", name: "zero", value: "7", help: "0"},
            %{
              flags: "E..V.......",
              name: "vsad",
              value: "8",
              help: "sum of absolute vertical differences"
            },
            %{
              flags: "E..V.......",
              name: "vsse",
              value: "9",
              help: "sum of squared vertical differences"
            },
            %{
              flags: "E..V.......",
              name: "nsse",
              value: "10",
              help: "noise preserving sum of squared differences"
            },
            %{
              flags: "E..V.......",
              name: "w53",
              value: "11",
              help: "5/3 wavelet, only used in snow"
            },
            %{
              flags: "E..V.......",
              name: "w97",
              value: "12",
              help: "9/7 wavelet, only used in snow"
            },
            %{flags: "E..V.......", name: "dctmax", value: "13", help: ""},
            %{flags: "E..V.......", name: "chroma", value: "256", help: ""},
            %{
              flags: "E..V.......",
              name: "msad",
              value: "15",
              help: "sum of absolute differences, median predicted"
            }
          ],
          declared_default: "sad"
        },
        %{
          flags: "E..V.......",
          name: "mblmin",
          type: :int,
          help: "minimum macroblock Lagrange factor (VBR) (from 1 to 32767) (default 236)",
          ranges: [%{max: "32767", min: "1"}],
          constants: [],
          declared_default: "236"
        },
        %{
          flags: "E..V.......",
          name: "mblmax",
          type: :int,
          help: "maximum macroblock Lagrange factor (VBR) (from 1 to 32767) (default 3658)",
          ranges: [%{max: "32767", min: "1"}],
          constants: [],
          declared_default: "3658"
        },
        %{
          flags: ".D.V.......",
          name: "skip_loop_filter",
          type: :int,
          help:
            "skip loop filtering process for the selected frames (from INT_MIN to INT_MAX) (default default)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [
            %{
              flags: ".D.V.......",
              name: "none",
              value: "-16",
              help: "discard no frame"
            },
            %{
              flags: ".D.V.......",
              name: "default",
              value: "0",
              help: "discard useless frames"
            },
            %{
              flags: ".D.V.......",
              name: "noref",
              value: "8",
              help: "discard all non-reference frames"
            },
            %{
              flags: ".D.V.......",
              name: "bidir",
              value: "16",
              help: "discard all bidirectional frames"
            },
            %{
              flags: ".D.V.......",
              name: "nointra",
              value: "24",
              help: "discard all frames except I frames"
            },
            %{
              flags: ".D.V.......",
              name: "nokey",
              value: "32",
              help: "discard all frames except keyframes"
            },
            %{
              flags: ".D.V.......",
              name: "all",
              value: "48",
              help: "discard all frames"
            }
          ],
          declared_default: "default"
        },
        %{
          flags: ".D.V.......",
          name: "skip_idct",
          type: :int,
          help:
            "skip IDCT/dequantization for the selected frames (from INT_MIN to INT_MAX) (default default)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [
            %{
              flags: ".D.V.......",
              name: "none",
              value: "-16",
              help: "discard no frame"
            },
            %{
              flags: ".D.V.......",
              name: "default",
              value: "0",
              help: "discard useless frames"
            },
            %{
              flags: ".D.V.......",
              name: "noref",
              value: "8",
              help: "discard all non-reference frames"
            },
            %{
              flags: ".D.V.......",
              name: "bidir",
              value: "16",
              help: "discard all bidirectional frames"
            },
            %{
              flags: ".D.V.......",
              name: "nointra",
              value: "24",
              help: "discard all frames except I frames"
            },
            %{
              flags: ".D.V.......",
              name: "nokey",
              value: "32",
              help: "discard all frames except keyframes"
            },
            %{
              flags: ".D.V.......",
              name: "all",
              value: "48",
              help: "discard all frames"
            }
          ],
          declared_default: "default"
        },
        %{
          flags: ".D.V.......",
          name: "skip_frame",
          type: :int,
          help:
            "skip decoding for the selected frames (from INT_MIN to INT_MAX) (default default)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [
            %{
              flags: ".D.V.......",
              name: "none",
              value: "-16",
              help: "discard no frame"
            },
            %{
              flags: ".D.V.......",
              name: "default",
              value: "0",
              help: "discard useless frames"
            },
            %{
              flags: ".D.V.......",
              name: "noref",
              value: "8",
              help: "discard all non-reference frames"
            },
            %{
              flags: ".D.V.......",
              name: "bidir",
              value: "16",
              help: "discard all bidirectional frames"
            },
            %{
              flags: ".D.V.......",
              name: "nointra",
              value: "24",
              help: "discard all frames except I frames"
            },
            %{
              flags: ".D.V.......",
              name: "nokey",
              value: "32",
              help: "discard all frames except keyframes"
            },
            %{
              flags: ".D.V.......",
              name: "all",
              value: "48",
              help: "discard all frames"
            }
          ],
          declared_default: "default"
        },
        %{
          flags: "E..V.......",
          name: "bidir_refine",
          type: :int,
          help:
            "refine the two motion vectors used in bidirectional macroblocks (from 0 to 4) (default 1)",
          ranges: [%{max: "4", min: "0"}],
          constants: [],
          declared_default: "1"
        },
        %{
          flags: "E..V.......",
          name: "keyint_min",
          type: :int,
          help: "minimum interval between IDR-frames (from INT_MIN to INT_MAX) (default 25)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [],
          declared_default: "25"
        },
        %{
          flags: "E..V.......",
          name: "refs",
          type: :int,
          help:
            "reference frames to consider for motion compensation (from INT_MIN to INT_MAX) (default 1)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [],
          declared_default: "1"
        },
        %{
          flags: "E..VA......",
          name: "trellis",
          type: :int,
          help: "rate-distortion optimal quantization (from INT_MIN to INT_MAX) (default 0)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..V.......",
          name: "mv0_threshold",
          type: :int,
          help: "(from 0 to INT_MAX) (default 256)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [],
          declared_default: "256"
        },
        %{
          flags: "E..VA......",
          name: "compression_level",
          type: :int,
          help: "(from INT_MIN to INT_MAX) (default -1)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [],
          declared_default: "-1"
        },
        %{
          flags: "ED..A......",
          name: "ch_layout",
          type: :channel_layout,
          help: "",
          ranges: [],
          constants: [],
          declared_default: nil
        },
        %{
          flags: "E..V.......",
          name: "rc_max_vbv_use",
          type: :float,
          help: "(from 0 to FLT_MAX) (default 0)",
          ranges: [%{max: "FLT_MAX", min: "0"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..V.......",
          name: "rc_min_vbv_use",
          type: :float,
          help: "(from 0 to FLT_MAX) (default 3)",
          ranges: [%{max: "FLT_MAX", min: "0"}],
          constants: [],
          declared_default: "3"
        },
        %{
          flags: "ED.VA......",
          name: "ticks_per_frame",
          type: :int,
          help: "(from 1 to INT_MAX) (default 1)",
          ranges: [%{max: "INT_MAX", min: "1"}],
          constants: [],
          declared_default: "1"
        },
        %{
          flags: "ED.V.......",
          name: "color_primaries",
          type: :int,
          help: "color primaries (from 1 to INT_MAX) (default unknown)",
          ranges: [%{max: "INT_MAX", min: "1"}],
          constants: [
            %{flags: "ED.V.......", name: "bt709", value: "1", help: "BT.709"},
            %{
              flags: "ED.V.......",
              name: "unknown",
              value: "2",
              help: "Unspecified"
            },
            %{
              flags: "ED.V.......",
              name: "bt470m",
              value: "4",
              help: "BT.470 M"
            },
            %{
              flags: "ED.V.......",
              name: "bt470bg",
              value: "5",
              help: "BT.470 BG"
            },
            %{
              flags: "ED.V.......",
              name: "smpte170m",
              value: "6",
              help: "SMPTE 170 M"
            },
            %{
              flags: "ED.V.......",
              name: "smpte240m",
              value: "7",
              help: "SMPTE 240 M"
            },
            %{flags: "ED.V.......", name: "film", value: "8", help: "Film"},
            %{flags: "ED.V.......", name: "bt2020", value: "9", help: "BT.2020"},
            %{
              flags: "ED.V.......",
              name: "smpte428",
              value: "10",
              help: "SMPTE 428-1"
            },
            %{
              flags: "ED.V.......",
              name: "smpte428_1",
              value: "10",
              help: "SMPTE 428-1"
            },
            %{
              flags: "ED.V.......",
              name: "smpte431",
              value: "11",
              help: "SMPTE 431-2"
            },
            %{
              flags: "ED.V.......",
              name: "smpte432",
              value: "12",
              help: "SMPTE 422-1"
            },
            %{
              flags: "ED.V.......",
              name: "jedec-p22",
              value: "22",
              help: "JEDEC P22"
            },
            %{
              flags: "ED.V.......",
              name: "ebu3213",
              value: "22",
              help: "EBU 3213-E"
            },
            %{
              flags: "ED.V.......",
              name: "unspecified",
              value: "2",
              help: "Unspecified"
            }
          ],
          declared_default: "unknown"
        },
        %{
          flags: "ED.V.......",
          name: "color_trc",
          type: :int,
          help: "color transfer characteristics (from 1 to INT_MAX) (default unknown)",
          ranges: [%{max: "INT_MAX", min: "1"}],
          constants: [
            %{flags: "ED.V.......", name: "bt709", value: "1", help: "BT.709"},
            %{
              flags: "ED.V.......",
              name: "unknown",
              value: "2",
              help: "Unspecified"
            },
            %{
              flags: "ED.V.......",
              name: "gamma22",
              value: "4",
              help: "BT.470 M"
            },
            %{
              flags: "ED.V.......",
              name: "bt470m",
              value: "4",
              help: "BT.470 M"
            },
            %{
              flags: "ED.V.......",
              name: "gamma28",
              value: "5",
              help: "BT.470 BG"
            },
            %{
              flags: "ED.V.......",
              name: "bt470bg",
              value: "5",
              help: "BT.470 BG"
            },
            %{
              flags: "ED.V.......",
              name: "smpte170m",
              value: "6",
              help: "SMPTE 170 M"
            },
            %{
              flags: "ED.V.......",
              name: "smpte240m",
              value: "7",
              help: "SMPTE 240 M"
            },
            %{flags: "ED.V.......", name: "linear", value: "8", help: "Linear"},
            %{flags: "ED.V.......", name: "log100", value: "9", help: "Log"},
            %{
              flags: "ED.V.......",
              name: "log316",
              value: "10",
              help: "Log square root"
            },
            %{
              flags: "ED.V.......",
              name: "iec61966-2-4",
              value: "11",
              help: "IEC 61966-2-4"
            },
            %{
              flags: "ED.V.......",
              name: "bt1361e",
              value: "12",
              help: "BT.1361"
            },
            %{
              flags: "ED.V.......",
              name: "iec61966-2-1",
              value: "13",
              help: "IEC 61966-2-1"
            },
            %{
              flags: "ED.V.......",
              name: "bt2020-10",
              value: "14",
              help: "BT.2020 - 10 bit"
            },
            %{
              flags: "ED.V.......",
              name: "bt2020-12",
              value: "15",
              help: "BT.2020 - 12 bit"
            },
            %{
              flags: "ED.V.......",
              name: "smpte2084",
              value: "16",
              help: "SMPTE 2084"
            },
            %{
              flags: "ED.V.......",
              name: "smpte428",
              value: "17",
              help: "SMPTE 428-1"
            },
            %{
              flags: "ED.V.......",
              name: "arib-std-b67",
              value: "18",
              help: "ARIB STD-B67"
            },
            %{
              flags: "ED.V.......",
              name: "unspecified",
              value: "2",
              help: "Unspecified"
            },
            %{flags: "ED.V.......", name: "log", value: "9", help: "Log"},
            %{
              flags: "ED.V.......",
              name: "log_sqrt",
              value: "10",
              help: "Log square root"
            },
            %{
              flags: "ED.V.......",
              name: "iec61966_2_4",
              value: "11",
              help: "IEC 61966-2-4"
            },
            %{
              flags: "ED.V.......",
              name: "bt1361",
              value: "12",
              help: "BT.1361"
            },
            %{
              flags: "ED.V.......",
              name: "iec61966_2_1",
              value: "13",
              help: "IEC 61966-2-1"
            },
            %{
              flags: "ED.V.......",
              name: "bt2020_10bit",
              value: "14",
              help: "BT.2020 - 10 bit"
            },
            %{
              flags: "ED.V.......",
              name: "bt2020_12bit",
              value: "15",
              help: "BT.2020 - 12 bit"
            },
            %{
              flags: "ED.V.......",
              name: "smpte428_1",
              value: "17",
              help: "SMPTE 428-1"
            }
          ],
          declared_default: "unknown"
        },
        %{
          flags: "ED.V.......",
          name: "colorspace",
          type: :int,
          help: "color space (from 0 to INT_MAX) (default unknown)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [
            %{flags: "ED.V.......", name: "rgb", value: "0", help: "RGB"},
            %{flags: "ED.V.......", name: "bt709", value: "1", help: "BT.709"},
            %{
              flags: "ED.V.......",
              name: "unknown",
              value: "2",
              help: "Unspecified"
            },
            %{flags: "ED.V.......", name: "fcc", value: "4", help: "FCC"},
            %{
              flags: "ED.V.......",
              name: "bt470bg",
              value: "5",
              help: "BT.470 BG"
            },
            %{
              flags: "ED.V.......",
              name: "smpte170m",
              value: "6",
              help: "SMPTE 170 M"
            },
            %{
              flags: "ED.V.......",
              name: "smpte240m",
              value: "7",
              help: "SMPTE 240 M"
            },
            %{flags: "ED.V.......", name: "ycgco", value: "8", help: "YCGCO"},
            %{
              flags: "ED.V.......",
              name: "bt2020nc",
              value: "9",
              help: "BT.2020 NCL"
            },
            %{
              flags: "ED.V.......",
              name: "bt2020c",
              value: "10",
              help: "BT.2020 CL"
            },
            %{
              flags: "ED.V.......",
              name: "smpte2085",
              value: "11",
              help: "SMPTE 2085"
            },
            %{
              flags: "ED.V.......",
              name: "chroma-derived-nc",
              value: "12",
              help: "Chroma-derived NCL"
            },
            %{
              flags: "ED.V.......",
              name: "chroma-derived-c",
              value: "13",
              help: "Chroma-derived CL"
            },
            %{flags: "ED.V.......", name: "ictcp", value: "14", help: "ICtCp"},
            %{flags: "ED.V.......", name: "ipt-c2", value: "15", help: "IPT-C2"},
            %{
              flags: "ED.V.......",
              name: "unspecified",
              value: "2",
              help: "Unspecified"
            },
            %{flags: "ED.V.......", name: "ycocg", value: "8", help: "YCGCO"},
            %{
              flags: "ED.V.......",
              name: "ycgco-re",
              value: "16",
              help: "YCgCo-R, even add."
            },
            %{
              flags: "ED.V.......",
              name: "ycgco-ro",
              value: "17",
              help: "YCgCo-R, odd add."
            },
            %{
              flags: "ED.V.......",
              name: "bt2020_ncl",
              value: "9",
              help: "BT.2020 NCL"
            },
            %{
              flags: "ED.V.......",
              name: "bt2020_cl",
              value: "10",
              help: "BT.2020 CL"
            }
          ],
          declared_default: "unknown"
        },
        %{
          flags: "ED.V.......",
          name: "color_range",
          type: :int,
          help: "color range (from 0 to INT_MAX) (default unknown)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [
            %{
              flags: "ED.V.......",
              name: "unknown",
              value: "0",
              help: "Unspecified"
            },
            %{
              flags: "ED.V.......",
              name: "tv",
              value: "1",
              help: "MPEG (219*2^(n-8))"
            },
            %{
              flags: "ED.V.......",
              name: "pc",
              value: "2",
              help: "JPEG (2^n-1)"
            },
            %{
              flags: "ED.V.......",
              name: "unspecified",
              value: "0",
              help: "Unspecified"
            },
            %{
              flags: "ED.V.......",
              name: "mpeg",
              value: "1",
              help: "MPEG (219*2^(n-8))"
            },
            %{
              flags: "ED.V.......",
              name: "jpeg",
              value: "2",
              help: "JPEG (2^n-1)"
            },
            %{
              flags: "ED.V.......",
              name: "limited",
              value: "1",
              help: "MPEG (219*2^(n-8))"
            },
            %{
              flags: "ED.V.......",
              name: "full",
              value: "2",
              help: "JPEG (2^n-1)"
            }
          ],
          declared_default: "unknown"
        },
        %{
          flags: "ED.V.......",
          name: "chroma_sample_location",
          type: :int,
          help: "chroma sample location (from 0 to INT_MAX) (default unknown)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [
            %{
              flags: "ED.V.......",
              name: "unknown",
              value: "0",
              help: "Unspecified"
            },
            %{flags: "ED.V.......", name: "left", value: "1", help: "Left"},
            %{flags: "ED.V.......", name: "center", value: "2", help: "Center"},
            %{
              flags: "ED.V.......",
              name: "topleft",
              value: "3",
              help: "Top-left"
            },
            %{flags: "ED.V.......", name: "top", value: "4", help: "Top"},
            %{
              flags: "ED.V.......",
              name: "bottomleft",
              value: "5",
              help: "Bottom-left"
            },
            %{flags: "ED.V.......", name: "bottom", value: "6", help: "Bottom"},
            %{
              flags: "ED.V.......",
              name: "unspecified",
              value: "0",
              help: "Unspecified"
            }
          ],
          declared_default: "unknown"
        },
        %{
          flags: "E..V.......",
          name: "slices",
          type: :int,
          help:
            "set the number of slices, used in parallelized encoding (from 0 to INT_MAX) (default 0)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "ED.VA......",
          name: "thread_type",
          type: :flags,
          help: "select multithreading type (default slice+frame)",
          ranges: [],
          constants: [
            %{flags: "ED.V.......", name: "slice", value: nil, help: ""},
            %{flags: "ED.V.......", name: "frame", value: nil, help: ""}
          ],
          declared_default: "slice+frame"
        },
        %{
          flags: "E...A......",
          name: "audio_service_type",
          type: :int,
          help: "audio service type (from 0 to 8) (default ma)",
          ranges: [%{max: "8", min: "0"}],
          constants: [
            %{
              flags: "E...A......",
              name: "ma",
              value: "0",
              help: "Main Audio Service"
            },
            %{flags: "E...A......", name: "ef", value: "1", help: "Effects"},
            %{
              flags: "E...A......",
              name: "vi",
              value: "2",
              help: "Visually Impaired"
            },
            %{
              flags: "E...A......",
              name: "hi",
              value: "3",
              help: "Hearing Impaired"
            },
            %{flags: "E...A......", name: "di", value: "4", help: "Dialogue"},
            %{flags: "E...A......", name: "co", value: "5", help: "Commentary"},
            %{flags: "E...A......", name: "em", value: "6", help: "Emergency"},
            %{flags: "E...A......", name: "vo", value: "7", help: "Voice Over"},
            %{flags: "E...A......", name: "ka", value: "8", help: "Karaoke"}
          ],
          declared_default: "ma"
        },
        %{
          flags: ".D..A......",
          name: "request_sample_fmt",
          type: :sample_fmt,
          help: "sample format audio decoders should prefer (default none)",
          ranges: [],
          constants: [],
          declared_default: "none"
        },
        %{
          flags: ".D...S.....",
          name: "sub_charenc",
          type: :string,
          help: "set input text subtitles character encoding",
          ranges: [],
          constants: [],
          declared_default: nil
        },
        %{
          flags: ".D...S.....",
          name: "sub_charenc_mode",
          type: :flags,
          help: "set input text subtitles character encoding mode (default 0)",
          ranges: [],
          constants: [
            %{flags: ".D...S.....", name: "do_nothing", value: nil, help: ""},
            %{flags: ".D...S.....", name: "auto", value: nil, help: ""},
            %{flags: ".D...S.....", name: "pre_decoder", value: nil, help: ""},
            %{flags: ".D...S.....", name: "ignore", value: nil, help: ""}
          ],
          declared_default: "0"
        },
        %{
          flags: ".D.V.......",
          name: "apply_cropping",
          type: :boolean,
          help: "(default true)",
          ranges: [],
          constants: [],
          declared_default: "true"
        },
        %{
          flags: ".D.V.......",
          name: "skip_alpha",
          type: :boolean,
          help: "Skip processing alpha (default false)",
          ranges: [],
          constants: [],
          declared_default: "false"
        },
        %{
          flags: "ED.V.......",
          name: "field_order",
          type: :int,
          help: "Field order (from 0 to 5) (default 0)",
          ranges: [%{max: "5", min: "0"}],
          constants: [
            %{flags: "ED.V.......", name: "progressive", value: "1", help: ""},
            %{flags: "ED.V.......", name: "tt", value: "2", help: ""},
            %{flags: "ED.V.......", name: "bb", value: "3", help: ""},
            %{flags: "ED.V.......", name: "tb", value: "4", help: ""},
            %{flags: "ED.V.......", name: "bt", value: "5", help: ""}
          ],
          declared_default: "0"
        },
        %{
          flags: "ED.VAS.....",
          name: "dump_separator",
          type: :string,
          help: "set information dump field separator",
          ranges: [],
          constants: [],
          declared_default: nil
        },
        %{
          flags: ".D.VAS.....",
          name: "codec_whitelist",
          type: :string,
          help: "List of decoders that are allowed to be used",
          ranges: [],
          constants: [],
          declared_default: nil
        },
        %{
          flags: "ED.VAS.....",
          name: "max_pixels",
          type: :int64,
          help: "Maximum number of pixels (from 0 to INT_MAX) (default INT_MAX)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [],
          declared_default: "INT_MAX"
        },
        %{
          flags: "ED..A......",
          name: "max_samples",
          type: :int64,
          help: "Maximum number of samples (from 0 to INT_MAX) (default INT_MAX)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [],
          declared_default: "INT_MAX"
        },
        %{
          flags: ".D.V.......",
          name: "hwaccel_flags",
          type: :flags,
          help: "(default ignore_level)",
          ranges: [],
          constants: [
            %{
              flags: ".D.V.......",
              name: "ignore_level",
              value: nil,
              help:
                "ignore level even if the codec level used is unknown or higher than the maximum supported level reported by the hardware driver"
            },
            %{
              flags: ".D.V.......",
              name: "allow_high_depth",
              value: nil,
              help:
                "allow to output YUV pixel formats with a different chroma sampling than 4:2:0 and/or other than 8 bits per component"
            },
            %{
              flags: ".D.V.......",
              name: "allow_profile_mismatch",
              value: nil,
              help:
                "attempt to decode anyway if HW accelerated decoder's supported profiles do not exactly match the stream"
            },
            %{
              flags: ".D.V.......",
              name: "unsafe_output",
              value: nil,
              help:
                "allow potentially unsafe hwaccel frame output that might require special care to process successfully"
            }
          ],
          declared_default: "ignore_level"
        },
        %{
          flags: ".D.V.......",
          name: "extra_hw_frames",
          type: :int,
          help:
            "Number of extra hardware frames to allocate for the user (from -1 to INT_MAX) (default -1)",
          ranges: [%{max: "INT_MAX", min: "-1"}],
          constants: [],
          declared_default: "-1"
        },
        %{
          flags: ".D.V.......",
          name: "discard_damaged_percentage",
          type: :int,
          help: "Percentage of damaged samples to discard a frame (from 0 to 100) (default 95)",
          ranges: [%{max: "100", min: "0"}],
          constants: [],
          declared_default: "95"
        },
        %{
          flags: ".D.VAS.....",
          name: "side_data_prefer_packet",
          type: {:array, :int},
          help:
            "Comma-separated list of side data types for which user-supplied (container) data is preferred over coded bytestream",
          ranges: [],
          constants: [
            %{flags: ".D..A......", name: "replaygain", value: "4", help: ""},
            %{flags: ".D..A......", name: "displaymatrix", value: "5", help: ""},
            %{flags: ".D..A......", name: "spherical", value: "21", help: ""},
            %{flags: ".D..A......", name: "stereo3d", value: "6", help: ""},
            %{
              flags: ".D..A......",
              name: "audio_service_type",
              value: "7",
              help: ""
            },
            %{
              flags: ".D..A......",
              name: "mastering_display_metadata",
              value: "20",
              help: ""
            },
            %{
              flags: ".D..A......",
              name: "content_light_level",
              value: "22",
              help: ""
            },
            %{flags: ".D..A......", name: "icc_profile", value: "28", help: ""}
          ],
          declared_default: nil
        }
      ]
    },
    %{
      name: "AVFormatContext",
      options: [
        %{
          flags: "ED.........",
          name: "avioflags",
          type: :flags,
          help: "(default 0)",
          ranges: [],
          constants: [
            %{
              flags: "ED.........",
              name: "direct",
              value: nil,
              help: "reduce buffering"
            }
          ],
          declared_default: "0"
        },
        %{
          flags: ".D.........",
          name: "probesize",
          type: :int64,
          help: "set probing size (from 32 to I64_MAX) (default 5000000)",
          ranges: [%{max: "I64_MAX", min: "32"}],
          constants: [],
          declared_default: "5000000"
        },
        %{
          flags: ".D.........",
          name: "formatprobesize",
          type: :int,
          help: "number of bytes to probe file format (from 0 to 2.14748e+09) (default 1048576)",
          ranges: [%{max: "2.14748e+09", min: "0"}],
          constants: [],
          declared_default: "1048576"
        },
        %{
          flags: "E..........",
          name: "packetsize",
          type: :int,
          help: "set packet size (from 0 to INT_MAX) (default 0)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "ED.........",
          name: "fflags",
          type: :flags,
          help: "(default autobsf)",
          ranges: [],
          constants: [
            %{
              flags: "E..........",
              name: "flush_packets",
              value: nil,
              help: "reduce the latency by flushing out packets immediately"
            },
            %{
              flags: ".D.........",
              name: "ignidx",
              value: nil,
              help: "ignore index"
            },
            %{
              flags: ".D.........",
              name: "genpts",
              value: nil,
              help: "generate pts"
            },
            %{
              flags: ".D.........",
              name: "nofillin",
              value: nil,
              help: "do not fill in missing values that can be exactly calculated"
            },
            %{
              flags: ".D.........",
              name: "noparse",
              value: nil,
              help: "disable AVParsers, this needs nofillin too"
            },
            %{
              flags: ".D.........",
              name: "igndts",
              value: nil,
              help: "ignore dts"
            },
            %{
              flags: ".D.........",
              name: "discardcorrupt",
              value: nil,
              help: "discard corrupted frames"
            },
            %{
              flags: ".D.........",
              name: "sortdts",
              value: nil,
              help: "try to interleave outputted packets by dts"
            },
            %{
              flags: ".D.........",
              name: "fastseek",
              value: nil,
              help: "fast but inaccurate seeks"
            },
            %{
              flags: ".D.........",
              name: "nobuffer",
              value: nil,
              help: "reduce the latency introduced by optional buffering"
            },
            %{
              flags: "E..........",
              name: "bitexact",
              value: nil,
              help: "do not write random/volatile data"
            },
            %{
              flags: "E.........P",
              name: "shortest",
              value: nil,
              help: "stop muxing with the shortest stream"
            },
            %{
              flags: "E..........",
              name: "autobsf",
              value: nil,
              help: "add needed bsfs automatically"
            }
          ],
          declared_default: "autobsf"
        },
        %{
          flags: ".D.........",
          name: "seek2any",
          type: :boolean,
          help: "allow seeking to non-keyframes on demuxer level when supported (default false)",
          ranges: [],
          constants: [],
          declared_default: "false"
        },
        %{
          flags: ".D.........",
          name: "analyzeduration",
          type: :int64,
          help:
            "specify how many microseconds are analyzed to probe the input (from 0 to I64_MAX) (default 0)",
          ranges: [%{max: "I64_MAX", min: "0"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: ".D.........",
          name: "cryptokey",
          type: :binary,
          help: "decryption key",
          ranges: [],
          constants: [],
          declared_default: nil
        },
        %{
          flags: ".D.........",
          name: "indexmem",
          type: :int,
          help:
            "max memory used for timestamp index (per stream) (from 0 to INT_MAX) (default 1048576)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [],
          declared_default: "1048576"
        },
        %{
          flags: ".D.........",
          name: "rtbufsize",
          type: :int,
          help:
            "max memory used for buffering real-time frames (from 0 to INT_MAX) (default 3041280)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [],
          declared_default: "3041280"
        },
        %{
          flags: "ED.........",
          name: "fdebug",
          type: :flags,
          help: "print specific debug info (default 0)",
          ranges: [],
          constants: [%{flags: "ED.........", name: "ts", value: nil, help: ""}],
          declared_default: "0"
        },
        %{
          flags: "ED.........",
          name: "max_delay",
          type: :int,
          help:
            "maximum muxing or demuxing delay in microseconds (from -1 to INT_MAX) (default -1)",
          ranges: [%{max: "INT_MAX", min: "-1"}],
          constants: [],
          declared_default: "-1"
        },
        %{
          flags: "E..........",
          name: "start_time_realtime",
          type: :int64,
          help:
            "wall-clock time when stream begins (PTS==0) (from I64_MIN to I64_MAX) (default I64_MIN)",
          ranges: [%{max: "I64_MAX", min: "I64_MIN"}],
          constants: [],
          declared_default: "I64_MIN"
        },
        %{
          flags: ".D.........",
          name: "fpsprobesize",
          type: :int,
          help: "number of frames used to probe fps (from -1 to 2.14748e+09) (default -1)",
          ranges: [%{max: "2.14748e+09", min: "-1"}],
          constants: [],
          declared_default: "-1"
        },
        %{
          flags: "E..........",
          name: "audio_preload",
          type: :int,
          help:
            "microseconds by which audio packets should be interleaved earlier (from 0 to 2.14748e+09) (default 0)",
          ranges: [%{max: "2.14748e+09", min: "0"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..........",
          name: "chunk_duration",
          type: :int,
          help: "microseconds for each chunk (from 0 to 2.14748e+09) (default 0)",
          ranges: [%{max: "2.14748e+09", min: "0"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..........",
          name: "chunk_size",
          type: :int,
          help: "size in bytes for each chunk (from 0 to 2.14748e+09) (default 0)",
          ranges: [%{max: "2.14748e+09", min: "0"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: ".D.........",
          name: "f_err_detect",
          type: :flags,
          help:
            "set error detection flags (deprecated; use err_detect, save via avconv) (default crccheck)",
          ranges: [],
          constants: [
            %{
              flags: ".D.........",
              name: "crccheck",
              value: nil,
              help: "verify embedded CRCs"
            },
            %{
              flags: ".D.........",
              name: "bitstream",
              value: nil,
              help: "detect bitstream specification deviations"
            },
            %{
              flags: ".D.........",
              name: "buffer",
              value: nil,
              help: "detect improper bitstream length"
            },
            %{
              flags: ".D.........",
              name: "explode",
              value: nil,
              help: "abort decoding on minor error detection"
            },
            %{
              flags: ".D.........",
              name: "ignore_err",
              value: nil,
              help: "ignore errors"
            },
            %{
              flags: ".D.........",
              name: "careful",
              value: nil,
              help:
                "consider things that violate the spec, are fast to check and have not been seen in the wild as errors"
            },
            %{
              flags: ".D.........",
              name: "compliant",
              value: nil,
              help: "consider all spec non compliancies as errors"
            },
            %{
              flags: ".D.........",
              name: "aggressive",
              value: nil,
              help: "consider things that a sane encoder shouldn't do as an error"
            }
          ],
          declared_default: "crccheck"
        },
        %{
          flags: ".D.........",
          name: "err_detect",
          type: :flags,
          help: "set error detection flags (default crccheck)",
          ranges: [],
          constants: [
            %{
              flags: ".D.........",
              name: "crccheck",
              value: nil,
              help: "verify embedded CRCs"
            },
            %{
              flags: ".D.........",
              name: "bitstream",
              value: nil,
              help: "detect bitstream specification deviations"
            },
            %{
              flags: ".D.........",
              name: "buffer",
              value: nil,
              help: "detect improper bitstream length"
            },
            %{
              flags: ".D.........",
              name: "explode",
              value: nil,
              help: "abort decoding on minor error detection"
            },
            %{
              flags: ".D.........",
              name: "ignore_err",
              value: nil,
              help: "ignore errors"
            },
            %{
              flags: ".D.........",
              name: "careful",
              value: nil,
              help:
                "consider things that violate the spec, are fast to check and have not been seen in the wild as errors"
            },
            %{
              flags: ".D.........",
              name: "compliant",
              value: nil,
              help: "consider all spec non compliancies as errors"
            },
            %{
              flags: ".D.........",
              name: "aggressive",
              value: nil,
              help: "consider things that a sane encoder shouldn't do as an error"
            }
          ],
          declared_default: "crccheck"
        },
        %{
          flags: ".D.........",
          name: "use_wallclock_as_timestamps",
          type: :boolean,
          help: "use wallclock as timestamps (default false)",
          ranges: [],
          constants: [],
          declared_default: "false"
        },
        %{
          flags: ".D.........",
          name: "skip_initial_bytes",
          type: :int64,
          help:
            "set number of bytes to skip before reading header and frames (from 0 to I64_MAX) (default 0)",
          ranges: [%{max: "I64_MAX", min: "0"}],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: ".D.........",
          name: "correct_ts_overflow",
          type: :boolean,
          help: "correct single timestamp overflows (default true)",
          ranges: [],
          constants: [],
          declared_default: "true"
        },
        %{
          flags: "E..........",
          name: "flush_packets",
          type: :int,
          help:
            "enable flushing of the I/O context after each packet (from -1 to 1) (default -1)",
          ranges: [%{max: "1", min: "-1"}],
          constants: [],
          declared_default: "-1"
        },
        %{
          flags: "E..........",
          name: "metadata_header_padding",
          type: :int,
          help:
            "set number of bytes to be written as padding in a metadata header (from -1 to INT_MAX) (default -1)",
          ranges: [%{max: "INT_MAX", min: "-1"}],
          constants: [],
          declared_default: "-1"
        },
        %{
          flags: "E..........",
          name: "output_ts_offset",
          type: :duration,
          help: "set output timestamp offset (default 0)",
          ranges: [],
          constants: [],
          declared_default: "0"
        },
        %{
          flags: "E..........",
          name: "max_interleave_delta",
          type: :int64,
          help:
            "maximum buffering duration for interleaving (from 0 to I64_MAX) (default 10000000)",
          ranges: [%{max: "I64_MAX", min: "0"}],
          constants: [],
          declared_default: "10000000"
        },
        %{
          flags: "ED.........",
          name: "f_strict",
          type: :int,
          help:
            "how strictly to follow the standards (deprecated; use strict, save via avconv) (from INT_MIN to INT_MAX) (default normal)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [
            %{
              flags: "ED.........",
              name: "very",
              value: "2",
              help:
                "strictly conform to a older more strict version of the spec or reference software"
            },
            %{
              flags: "ED.........",
              name: "strict",
              value: "1",
              help:
                "strictly conform to all the things in the spec no matter what the consequences"
            },
            %{flags: "ED.........", name: "normal", value: "0", help: ""},
            %{
              flags: "ED.........",
              name: "unofficial",
              value: "-1",
              help: "allow unofficial extensions"
            },
            %{
              flags: "ED.........",
              name: "experimental",
              value: "-2",
              help: "allow non-standardized experimental variants"
            }
          ],
          declared_default: "normal"
        },
        %{
          flags: "ED.........",
          name: "strict",
          type: :int,
          help: "how strictly to follow the standards (from INT_MIN to INT_MAX) (default normal)",
          ranges: [%{max: "INT_MAX", min: "INT_MIN"}],
          constants: [
            %{
              flags: "ED.........",
              name: "very",
              value: "2",
              help:
                "strictly conform to a older more strict version of the spec or reference software"
            },
            %{
              flags: "ED.........",
              name: "strict",
              value: "1",
              help:
                "strictly conform to all the things in the spec no matter what the consequences"
            },
            %{flags: "ED.........", name: "normal", value: "0", help: ""},
            %{
              flags: "ED.........",
              name: "unofficial",
              value: "-1",
              help: "allow unofficial extensions"
            },
            %{
              flags: "ED.........",
              name: "experimental",
              value: "-2",
              help: "allow non-standardized experimental variants"
            }
          ],
          declared_default: "normal"
        },
        %{
          flags: ".D.........",
          name: "max_ts_probe",
          type: :int,
          help:
            "maximum number of packets to read while waiting for the first timestamp (from 0 to INT_MAX) (default 50)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [],
          declared_default: "50"
        },
        %{
          flags: "E..........",
          name: "avoid_negative_ts",
          type: :int,
          help: "shift timestamps so they start at 0 (from -1 to 2) (default auto)",
          ranges: [%{max: "2", min: "-1"}],
          constants: [
            %{
              flags: "E..........",
              name: "auto",
              value: "-1",
              help: "enabled when required by target format"
            },
            %{
              flags: "E..........",
              name: "disabled",
              value: "0",
              help: "do not change timestamps"
            },
            %{
              flags: "E..........",
              name: "make_non_negative",
              value: "1",
              help: "shift timestamps so they are non negative"
            },
            %{
              flags: "E..........",
              name: "make_zero",
              value: "2",
              help: "shift timestamps so they start at 0"
            }
          ],
          declared_default: "auto"
        },
        %{
          flags: "ED.........",
          name: "dump_separator",
          type: :string,
          help: "set information dump field separator (default \", \")",
          ranges: [],
          constants: [],
          declared_default: "\", \""
        },
        %{
          flags: ".D.........",
          name: "codec_whitelist",
          type: :string,
          help: "List of decoders that are allowed to be used",
          ranges: [],
          constants: [],
          declared_default: nil
        },
        %{
          flags: ".D.........",
          name: "format_whitelist",
          type: :string,
          help: "List of demuxers that are allowed to be used",
          ranges: [],
          constants: [],
          declared_default: nil
        },
        %{
          flags: ".D.........",
          name: "protocol_whitelist",
          type: :string,
          help: "List of protocols that are allowed to be used",
          ranges: [],
          constants: [],
          declared_default: nil
        },
        %{
          flags: ".D.........",
          name: "protocol_blacklist",
          type: :string,
          help: "List of protocols that are not allowed to be used",
          ranges: [],
          constants: [],
          declared_default: nil
        },
        %{
          flags: ".D.........",
          name: "max_streams",
          type: :int,
          help: "maximum number of streams (from 0 to INT_MAX) (default 1000)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [],
          declared_default: "1000"
        },
        %{
          flags: ".D.........",
          name: "skip_estimate_duration_from_pts",
          type: :boolean,
          help: "skip duration calculation in estimate_timings_from_pts (default false)",
          ranges: [],
          constants: [],
          declared_default: "false"
        },
        %{
          flags: ".D.........",
          name: "max_probe_packets",
          type: :int,
          help: "Maximum number of packets to probe a codec (from 0 to INT_MAX) (default 2500)",
          ranges: [%{max: "INT_MAX", min: "0"}],
          constants: [],
          declared_default: "2500"
        },
        %{
          flags: ".D.........",
          name: "duration_probesize",
          type: :int64,
          help:
            "Maximum number of bytes to probe the durations of the streams in estimate_timings_from_pts (from 0 to I64_MAX) (default 0)",
          ranges: [%{max: "I64_MAX", min: "0"}],
          constants: [],
          declared_default: "0"
        }
      ]
    },
    %{
      name: "AVIOContext",
      options: [
        %{
          flags: ".D.........",
          name: "protocol_whitelist",
          type: :string,
          help: "List of protocols that are allowed to be used",
          ranges: [],
          constants: [],
          declared_default: nil
        }
      ]
    },
    %{
      name: "URLContext",
      options: [
        %{
          flags: ".D.........",
          name: "protocol_whitelist",
          type: :string,
          help: "List of protocols that are allowed to be used",
          ranges: [],
          constants: [],
          declared_default: nil
        },
        %{
          flags: ".D.........",
          name: "protocol_blacklist",
          type: :string,
          help: "List of protocols that are not allowed to be used",
          ranges: [],
          constants: [],
          declared_default: nil
        },
        %{
          flags: "ED.........",
          name: "rw_timeout",
          type: :int64,
          help: "Timeout for IO operations (in microseconds) (from 0 to I64_MAX) (default 0)",
          ranges: [%{max: "I64_MAX", min: "0"}],
          constants: [],
          declared_default: "0"
        }
      ]
    }
  ]
}
