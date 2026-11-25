# Coverage

- Use the smallest suite that gives confidence in the change. Choose
  checks in proportion to risk and preserve mandatory contract, release,
  and platform checks.
- Review existing coverage before adding tests. Prioritize critical
  behavior, meaningful edge cases, and regressions. Parameterize cases
  that exercise the same behavior.
- When a defect exposes a gap, cover the specific failure at the
  smallest test layer that reproduces it. Consolidate overlapping cases
  when the remaining tests preserve their meaningful coverage.
