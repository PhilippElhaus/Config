# Benchmarks

- Compare runner migrations and selectors against the existing suite.
  Use the same environment, worker count, and test scope for before and
  after measurements.
- Report elapsed time, test counts, and the selector's own overhead.
  Include a real source change and a case that exercises the full-suite
  fallback.
- Prefer a small improvement to the existing harness when it gives the
  same coverage and measured benefit as adding another framework.
