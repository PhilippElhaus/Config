# Execution

- Run independent tests in parallel within available resources. Isolate
  mutable state, ports, and files. Keep setup and fixture overhead low.
- Run independent ShellSpec examples in parallel. Set the worker count
  to the CPU and memory available to the suite.
- Verify interface changes in the running application. Exercise the
  changed flow at representative narrow and wide sizes. Check both
  themes when the change affects appearance.
- Run checks that depend on the desktop, hardware, or installed runtime
  on the required platform. Keep the portable checks in CI where they fit.
