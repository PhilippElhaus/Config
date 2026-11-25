# Services

- Prefer Docker Compose for small multi-service deployments when the
  host already supports it. Keep each stack independently reproducible
  and persistent application data outside replaceable containers.
- Size services for the expected load and availability. Prefer a small
  existing service or a consumption tier when it meets those needs.
  Compare running cost before adding a dedicated service.
- Prefer Ansible for repeatable host configuration and fleet maintenance.
  Keep shared automation in roles and host-specific choices in inventory.
- For host or service changes with shared impact, inspect the current
  state and use a dry run where available. Keep a recovery path and
  check service health after applying the change.
