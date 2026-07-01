# Data SLAs & quality policy

Portfolio-grade **expectations** for Crypto Pulse — enforced by Great Expectations, dbt tests, and Metabase Freshness dashboards.

## Scope

| Dimension | Target |
|-----------|--------|
| **Assets** | `bitcoin`, `ethereum`, `solana` |
| **Sources** | `coingecko`, `binance` |
| **Freshness (raw)** | Last event ≤ **10 minutes** (`GE_FRESHNESS_MINUTES`) |
| **Volume (raw, 24h)** | ≥ **1 row per source** (`GE_MIN_ROWS_PER_SOURCE`) |
| **Coverage (raw, 24h)** | All **3 coins present per source** (`GE_MIN_COINS_PER_SOURCE`) |
| **Gold latest** | Exactly **1 row per coin** in `mart_latest_prices` |
| **Multi-source compare** | Rows in `mart_source_price_comparison` when both sources are up |

## SLA status labels (Metabase / ops)

Used in `gold.mart_freshness_by_source`:

| Status | Condition |
|--------|-----------|
| **OK** | Last tick ≤ 10 minutes ago |
| **WARN** | 10–30 minutes |
| **FAIL** | > 30 minutes |

## Ownership (conceptual)

| Zone | Owner component | Consumer |
|------|-----------------|----------|
| **Ingest** | `ingest`, `binance-ingest` | Kafka |
| **Raw stream** | Flink SQL | Postgres raw, MinIO lake |
| **Silver / gold** | dbt (Dagster schedule) | Metabase, GX |
| **Quality gates** | dbt tests + `quality/validate.py` | CI, transform job |

## On failure

1. **Ingest stale** — check API/WS logs, Grafana alerts (`CoingeckoPollStale`, `BinancePublishStale`).
2. **Flink job down** — `FlinkNoRunningJobs` alert; resubmit via `docker compose up --build flink-submitter`.
3. **GX fails in transform** — Dagster job marks run failed; inspect `docker logs crypto-pulse-transform`.
4. **dbt tests fail** — fix models or upstream raw data before gold is trusted.

## Out of scope (honest portfolio limits)

- 99.9% uptime / HA Kafka or Flink
- Financial-grade price accuracy or trading SLAs
- PII or regulatory retention policies

See [ARCHITECTURE.md](ARCHITECTURE.md#known-limitations-honest-scope) for production next steps.
