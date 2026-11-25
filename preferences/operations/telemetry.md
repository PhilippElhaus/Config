# Telemetry

- Reuse Prometheus metrics and Grafana dashboards where that stack is
  established. Keep one authoritative source for each metric.
- Preserve units and labels across producers, queries, dashboards, and
  alerts. Keep detailed telemetry available for diagnosis and give the
  overview only the metrics that inform an action.
