# Runners

- Prefer Vitest over Jest for JavaScript and TypeScript.
- Prefer Python rstest where compatibility with the interpreter,
  fixtures, and plugins has been verified.
- Prefer ShellSpec over Bats for Bash. Use ShellSpec for new suites and
  planned conversions. Keep Bats when a project constraint requires it
  or while transitioning an existing suite.
- Use Cargo's native test runner for Rust unless a reliable alternative
  shows a measured benefit.
- Keep established runners when they serve the project well. Show
  equivalent behavior, compatibility, and a measured benefit before a
  migration.
