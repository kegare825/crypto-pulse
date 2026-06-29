# Architecture & design decisions

Crypto Pulse is a **portfolio-grade data platform** — a simplified lakehouse that demonstrates end-to-end data engineering patterns without pretending to be a regulated trading system.

## Data flow

```
Sources          Kafka (raw stream)     Processing           Warehouse           Consumption
─────────        ─────────────────      ──────────           ─────────           ───────────
CoinGecko REST → coingecko.prices.raw ─┐
                                       ├→ Flink SQL ──→ raw.crypto_prices
Binance WS     → binance.trades.raw  ─┘        │
                                                ↓
                                         dbt (silver → gold)
                                                ↓
                              Great Expectations + Metabase / Grafana
```

## Zone model

| Zone | Storage | Tooling | Purpose |
|------|---------|---------|---------|
| **Raw** | Kafka + `raw.*` | Flink SQL | Immutable landing, minimal transformation |
| **Silver** | `silver.*` | dbt | Clean types, dedupe, incremental hygiene |
| **Gold** | `gold.*` | dbt | Business marts for BI and comparisons |

## Key decisions

### Two Kafka topics (not one)

CoinGecko and Binance have different semantics (REST poll vs WS trades), throughput, and retention needs. Separate topics keep ownership clear and let Flink attach **independent consumer groups** per source.

### Flink SQL (not PyFlink)

The streaming layer is intentionally **declarative SQL**: easier to review in a portfolio, closer to how many teams run Flink in production, and keeps Python limited to ingest where I/O libraries shine.

### PostgreSQL as warehouse (not S3/MinIO yet)

For this scope, a single Postgres instance keeps the stack runnable on one machine (`docker compose up`). The zone pattern still maps cleanly to a future object-store lake — raw events would land in S3/Parquet instead of (or in addition to) JDBC.

### Binance throttle (~1 msg/s per coin)

Binance trades arrive at high frequency; CoinGecko polls every ~60s. Throttling avoids drowning Postgres and makes **cross-source comparison** meaningful (similar temporal granularity).

### `mart_latest_prices` stays CoinGecko-only

Existing BI dashboards expect one row per coin from the “reference” aggregator. Multi-source truth lives in `mart_latest_prices_by_source` and `mart_source_price_comparison`.

### Quality in two layers

- **dbt tests** — schema constraints at transform time (fast, versioned with models).
- **Great Expectations** — runtime freshness and cross-zone sanity checks on a schedule.

### Observability split

- **Grafana + Prometheus** — pipeline health (throughput, lag, errors, Flink job count).
- **Metabase** — business questions on `gold.*`.

Alert rules live in `observability/prometheus/alerts.yml` and are validated in CI with `promtool`.

## Event contract

All producers emit the same JSON shape, validated in CI against `contracts/crypto_price_event.schema.json`:

```json
{
  "coin_id": "bitcoin",
  "symbol": "btc",
  "price_usd": 60000.0,
  "market_cap": null,
  "change_24h": null,
  "event_time": "2026-06-29T15:30:00+00:00",
  "source": "coingecko"
}
```

## Known limitations (honest scope)

| Area | Current state | Production next step |
|------|---------------|---------------------|
| HA | Single broker, single Flink TM | Multi-AZ Kafka, Flink checkpoint store |
| Secrets | Default passwords in compose | Secrets manager + env injection |
| Deploy | Docker Compose local | Terraform + managed RDS/MSK |
| Flink ops | Manual `flink-submitter` | Savepoints, auto-resubmit, alert on job loss |
| DLQ | Bad JSON silently skipped | Dead-letter topic + monitoring |

## CI pipeline

On every push/PR (`.github/workflows/ci.yml`):

1. **pytest** — `coingecko_normalize`, `trade_normalize`, JSON Schema contract
2. **dbt parse/compile** — model graph integrity without a live DB
3. **docker compose config** + **promtool check rules** — infra sanity

This gives reviewers confidence the project is maintained, not a one-off demo.
