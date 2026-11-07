# English variants of the monitoring files

The provisioned Grafana dashboard and the Prometheus alert rules carry French
panel titles and alert texts. For an English session, swap in these files:

```bash
cp en/formini-tasks.json grafana/dashboards/formini-tasks.json
cp en/alerts.yml         prometheus/alerts.yml
docker compose restart prometheus grafana
```

Queries, metric names, thresholds and layout are identical to the French files.
