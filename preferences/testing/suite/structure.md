# Structure

- Keep test files focused and aim for fewer than 200 lines where
  practical. Group tests by concern. Create categories such as unit,
  integration, end-to-end, smoke, edge case, and regression only as needed.
- Prefer a root `tests/` directory. Keep established discovery
  conventions, such as Rust unit tests beside the private code they test.
