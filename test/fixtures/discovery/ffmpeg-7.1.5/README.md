# FFmpeg 7.1.5 Metadata Fixtures

Captured from the build described in `version.txt`, using:

```sh
ffmpeg -hide_banner -v quiet -encoders
ffmpeg -hide_banner -v quiet -h encoder=libx264
ffmpeg -hide_banner -h full
```

The other catalogs and help topics use their corresponding CLI arguments.
Component help files are complete. Large catalogs retain their original
headers and selected rows; whitespace and descriptions are unchanged.
`shared-excerpt.txt` is a contiguous full-help excerpt containing the complete
AVFormatContext, AVIOContext, and URLContext sections and neighboring private
options. Tests use these captures without requiring the same installed build.

Synthetic compatibility and malformed-output cases live directly in the tests;
they are not presented as captures from other FFmpeg versions.
