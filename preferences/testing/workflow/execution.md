# Execution

- Run independent tests in parallel within available resources. Isolate
  mutable state, ports, and files. Keep setup and fixture overhead low.
- Run independent ShellSpec examples in parallel. Set the worker count
  to the CPU and memory available to the suite.
