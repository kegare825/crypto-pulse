# Screenshots (portfolio)

The main README embeds the captures below. To (re)generate them, use the **demo profile** so charts are dense without waiting hours:

```bash
cp .env.demo .env                    # 15s CoinGecko polling, 60s Dagster refresh
docker compose up --build
bash scripts/seed_demo_history.sh    # 7 days of hourly history for daily trend charts
METABASE_EMAIL=... METABASE_PASSWORD=... python3 metabase/setup_dashboard.py
```

Wait ~5 minutes (a couple of ingest cycles + one Dagster run), then capture:

| File | What to show | Where |
|------|--------------|-------|
| `metabase-source-comparison.png` | CoinGecko vs Binance spread table | Metabase → Crypto Pulse — Prices |
| `metabase-spread-chart.png` | Spread % by coin bar chart | Metabase → Crypto Pulse — Prices |
| `grafana-pipeline-health.png` | Grafana ops dashboard | http://localhost:3001 |
| `minio-partitions.png` | MinIO browser: `source=/coin_id=/dt=` paths | http://localhost:9001 |
| `dagster-transform-job.png` | Dagster UI: successful `transform_job` | http://localhost:3002 → Runs |

Capture tips:

- Use a clean browser window (no bookmarks bar), ~1440px wide, light theme for Metabase/Dagster.
- For Grafana pick the last 15–30 min range so the demo polling (15s) fills the panels.
- For `mart_daily_prices` trend views, the seeded history gives 7 days of points.

When done, revert to production-like defaults:

```bash
cp .env.example .env
docker compose up -d --force-recreate ingest transform
```
