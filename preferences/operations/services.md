# Services

- Prefer Docker Compose for small multi-service deployments when the
  host already supports it. Keep each stack independently reproducible
  and persistent application data outside replaceable containers.
- Prefer Ansible for repeatable host configuration and fleet maintenance.
  Keep shared automation in roles and host-specific choices in inventory.
