# Selection

## Projects

- Prefer Nx for test impact analysis (TIA) where the repository fits it.
  Use `nx affected` to find affected projects and downstream consumers.
  Keep independent repositories separate.

## Tests

- Use Nx to coordinate a second stage inside each affected project.
  Select tests down to individual functions or cases where reliable
  dependency or coverage data supports that granularity.
- Use the runner's change-aware selection where it fits. Examples
  include Vitest's related test-file selection and compatible Python
  rstest selection. Use verified dependency or per-test coverage maps
  for Rust and Bash where available.
- Account for shared fixtures, helpers, generated inputs, and dynamic
  dependencies. Verify support in the installed runner before narrowing
  a test run.
- Check selection with representative source changes. Show which
  projects and tests ran, which were skipped, and why.

## Fallback

- Use both levels for pull requests when reliable. Run the full relevant
  suite when the graph or change base is incomplete, stale, or uncertain.
- Reuse cached results only when source, dependencies, configuration, and
  tool versions match. Use a bounded Git history fetch when it gives a
  reliable change base.
- Run the complete suite on `main`. Preserve required contract, release,
  and platform checks. Use scheduled regression and coverage runs when
  they add useful assurance.
