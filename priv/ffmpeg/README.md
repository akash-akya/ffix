# FFmpeg Metadata

`metadata.exs` stores recorded codec, format, and AVOption metadata. Macros use it
to define helpers, docs, and typespecs at compile time without querying FFmpeg.

Refresh: `mix ffix.refresh.metadata --ffmpeg /usr/bin/ffmpeg`
