# Codec and format helper metadata

`helpers.exs` is normalized discovery output captured from FFmpeg 7.1.5.
It records the executable's version/configuration, shared AVOptions sections,
and complete private help for the registrations selected by
`Mix.Tasks.Ffix.Gen.Helpers`. Original option owners, types, reported defaults,
ranges, constants, and properties are retained. This is a generation input,
not a runtime cache or a claim about other installed FFmpeg builds.

From the FFix repository:

```sh
# Deterministically regenerate functions, docs, and option types from this file.
mix ffix.gen.helpers

# Fail if checked-in generated code differs, without refreshing metadata.
mix ffix.gen.helpers --check

# Explicitly replace the baseline using a build with all selected registrations.
mix ffix.gen.helpers --refresh --ffmpeg /usr/bin/ffmpeg
```

Review both metadata and generated-code diffs after a refresh. Generation only
replaces the marked sections of the four public modules. Demuxer aliases are
not reused as muxer aliases. Names that are not ordinary Elixir identifiers
(such as `3gp`) remain accessible through the generic `named` constructors.

Private writable options are supplemented with a deliberately selected set of
applicable shared options. Their declarations are kept distinct in documentation
and represented as alternatives for basic shape checks. Read-only fields are
not offered as setter options. Numeric ranges and string values are not treated
as complete validation sets; FFmpeg retains the final say.

The generated functions and keyword types support discovery through IEx/ExDoc
and editor tooling. Keyword/value completion behavior depends on the language
server; typespecs do not guarantee an exhaustive completion menu.

Normal command construction does not read this file or invoke discovery.
The legacy `FFix.Filter` compile-time discovery path remains separate and
unchanged.
