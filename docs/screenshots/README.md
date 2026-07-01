# Screenshots (portfolio)

Add captures here after importing Metabase dashboards and running the full stack:

```bash
METABASE_EMAIL=... METABASE_PASSWORD=... python3 metabase/setup_dashboard.py
docker compose up --build
bash scripts/verify_lake.sh
```

| File | What to show |
|------|----------------|
| `metabase-source-comparison.png` | CoinGecko vs Binance spread table |
| `metabase-spread-chart.png` | Spread % by coin bar chart |
| `grafana-pipeline-health.png` | Grafana ops dashboard |
| `minio-partitions.png` | MinIO browser: `source=/coin_id=/dt=` paths |
| `dagster-transform-job.png` | Dagster UI: successful `transform_job` |

Link from the main README with relative paths, e.g. `docs/screenshots/metabase-source-comparison.png`.

Example markdown once files exist:

```markdown
![Source comparison](docs/screenshots/metabase-source-comparison.png)
```
