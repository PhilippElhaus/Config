# Git

- Keep `main` as the single long-lived branch. Start from updated
  `main` and keep feature branches small and short-lived.
- Keep the canonical checkout in place. Put extra worktrees under the
  repository's ignored `.worktrees/<task>/` directory by default. Check
  for an existing task worktree before creating one and preserve
  unrelated work.
- After a branch is merged, remove the merged branch and prune stale
  remote-tracking refs. Preserve unique work.
