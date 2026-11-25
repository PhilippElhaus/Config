# Modules

- Start with the existing implementation and conventions. Fix the cause
  in the smallest coherent place. Consolidate duplicate behavior when
  it reduces maintenance and preserves the behavior callers rely on.
- In Rust, give each module a clear responsibility. Aim for roughly 200
  lines when it fits the concern.
- Keep `unsafe` code small. Document the conditions that make it safe.
