# Metabase BI export

Version-controlled business dashboards on schema **`gold`**: native SQL questions + JSON manifests imported via API.

## Contents

| File | Description |
|------|-------------|
| `questions/*.sql` | Native SQL for each card |
| `exports/*-dashboard.json` | Dashboard layout (collection, cards, positions) |
| `setup_dashboard.py` | Create or update everything via Metabase API |

## Dashboard: **Crypto Pulse — Prices**

1. **Source price comparison** — CoinGecko vs Binance spread table  
2. **Latest prices by source** — last tick per coin and source  
3. **Latest prices (CoinGecko)** — compatible with `mart_latest_prices`  
4. **Daily average price by source** — time series  
5. **Spread % by coin** — bar chart  

## Dashboard: **Crypto Pulse — Data Quality**

1. **Volume by zone and source** — raw / silver / gold counts (gold marts only in SQL)  
2. **Gold null and sanity checks** — null or non-positive prices  

## Dashboard: **Crypto Pulse — Freshness & SLA**

1. **Freshness by source** — minutes since last event (10 min SLA)  
2. **Source timestamp gap** — CoinGecko vs Binance latest tick delta per coin  

Manifests in `exports/`:

- `crypto-pulse-prices-dashboard.json`
- `crypto-pulse-quality-dashboard.json`
- `crypto-pulse-freshness-dashboard.json`

By default the script imports **all** `*-dashboard.json` files. Single manifest:

```bash
METABASE_MANIFEST=exports/crypto-pulse-quality-dashboard.json python3 metabase/setup_dashboard.py
```

## Prerequisites

1. Stack running with data in gold (`docker compose up`, wait for transform/dbt).
2. Metabase at http://localhost:3000 with admin account created.
3. PostgreSQL connection in Metabase:
   - Host: `postgres` (from Docker) or `localhost`
   - Database: `cryptopulse`
   - User / password: `pulse` / `pulse`
   - Visible schema: **`gold`** only (all dashboard SQL uses `gold.*`)

## Automated import (recommended)

```bash
METABASE_EMAIL=you@example.com \
METABASE_PASSWORD=your_password \
python3 metabase/setup_dashboard.py
```

Optional variables:

| Variable | Default |
|----------|---------|
| `METABASE_URL` | `http://localhost:3000` |
| `METABASE_EMAIL` | *(required)* |
| `METABASE_PASSWORD` | *(required)* |

The script is **idempotent**: re-run after changing SQL or layout to update existing cards/dashboards.

Final URLs are printed as `http://localhost:3000/dashboard/<id>`.

## Manual import

1. **New collection** → "Crypto Pulse"
2. For each file in `questions/`: **New → SQL query** → paste SQL → save to collection
3. **New dashboard** → add the questions

## Screenshots for README / LinkedIn

After import, capture:

- **Source price comparison** table (multi-source)
- **Spread % by coin** chart

Save under `docs/screenshots/` (e.g. `metabase-spread.png`) and link from the main README.

## Updating the export

1. Edit SQL in `questions/` or layout in `exports/*-dashboard.json`
2. Re-run `setup_dashboard.py`
3. Commit changes to git
