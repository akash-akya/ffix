## Goal and Boundaries

Model FFmpeg graphs and commands as explicit Elixir data. Keep parsing, modeling, serialization, command construction, and execution separate; keep I/O at the edges.

Keep metadata discovery and code generation explicit and reproducible. Do not add automatic scans to compilation or command construction.

## Code Style

- Optimize for readability, not fewer lines. Use descriptive names and explicit intermediate values.
- Keep control flow shallow. Prefer `case` inside a function for value dispatch. Use multiple function heads when they clarify recursion, not to scatter small decisions.
- Use clear block forms for conditionals and loops. Avoid complex inline `if`/`for` expressions and parsing or filtering hidden in comprehension qualifiers.
- Extract cohesive responsibilities, not tiny wrappers or helpers that merely hide nesting. Avoid speculative frameworks and towers of abstractions.
- Validate external inputs where it matters; trust established internal invariants. Do not mask programmer errors with defensive fallbacks or broad rescues.
- Use named NimbleParsec combinators for structured parsing. Reserve regex for simple matches.
- Preserve FFmpeg semantics and reported metadata; do not invent defaults or validation rules.
- Write concise comments explaining why, not restating what the code does. Add docs and typespecs where they clarify contracts.

## Changes and Tests

Keep patches focused. Add tests for useful behavior and regressions, not implementation details. Run relevant tests and the project formatter for code changes.
