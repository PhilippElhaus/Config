# Labs

- Prefer a prepared Linux lab through MCP when it supports the coding,
  testing, or build task. Use the native platform for checks that depend
  on its actual runtime or interface.
- Use a task-owned lab session and import only the inputs it needs. Use
  an isolated browser for ordinary previews. Use the signed-in desktop
  when a check depends on the user's account or desktop state.
- Choose a GPU lab explicitly when the workload benefits. Use CUDA with
  CuPy or Numba for suitable compute work and FFmpeg with NVENC for
  supported hardware encoding.
