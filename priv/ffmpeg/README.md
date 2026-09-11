# FFmpeg Metadata

`metadata.exs` records selected codecs/formats and the full filter catalog with
parsed help and FFmpeg build provenance. Macros define helpers, docs, and types
from it without querying FFmpeg during compilation or normal runtime use.

Refresh: `mix ffix.refresh.metadata --ffmpeg /usr/bin/ffmpeg`

Use the same FFmpeg build to reproduce a capture. Refresh is atomic and rejects
missing previously recorded filters; intentional removals require editing the
baseline first.

`checksums.exs` separately pins BtbN binary downloads. Update it explicitly with
`mix ffix.ffmpeg.checksum --release TAG`; download with
`mix ffix.ffmpeg.fetch --variant gpl` (or `lgpl`). Both default to branch `9.0`.
