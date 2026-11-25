# Builds

- Build release artifacts off the deployment host by default. Use a
  compatible build environment and locked dependencies.
- Keep target-specific checks in the owning repository. Verify the built
  artifact for the target runtime and preserve its rollback path.
