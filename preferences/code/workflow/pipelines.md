# Pipelines

- Keep GitHub Actions YAML short. Put substantial shell logic in
  versioned, testable helpers. Use named flags to make inputs explicit.
- Use forward slashes in workflow path literals so the same workflow can
  address files on Windows and Linux runners.
- Keep dependencies on supported versions. Verify upgrades and preserve
  required checks when simplifying a pipeline.
