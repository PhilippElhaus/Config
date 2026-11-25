# Caches

- Group generated tool caches under one ignored repository directory,
  such as `.cache/`. Give each tool a subdirectory. Keep installed
  dependencies, release artifacts, and backups in their own locations.
- Reuse dependency downloads and build results with matching lockfiles,
  inputs, configuration, and tool versions. Keep shared package caches
  in their normal tool-managed locations.
