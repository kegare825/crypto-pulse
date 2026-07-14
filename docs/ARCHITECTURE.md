# Architecture & design decisions

Crypto Pulse is a **portfolio-grade data platform** — a simplified lakehouse that demonstrates end-to-end data engineering patterns without pretending to be a regulated trading system.

## Data flow

```
Sources          Kafka (raw stream)     Processing           Storage + Serving    Consumption
─────────        ─────────────────      ──────────           ─────────────────    ───────────
CoinGecko REST → coingecko.prices.raw ─┐
                                       ├→ Flink SQL ──→ MinIO (Parquet raw)  ─┐
Binance WS     → binance.trades.raw  ─┘        │         Postgres raw/silver/gold
                                                └→ (dual write)
                                                         ↓
                                                  dbt (silver → gold)
                                                         ↓
                              Great Expectations + Metabase / Grafana
```

See [docs/DATA_LAKE.md](DATA_LAKE.md) for storage vs serving split and Iceberg roadmap.

Architecture Decision Records: [docs/adr/README.md](adr/README.md). Data SLAs: [docs/SLA.md](SLA.md). Incident postmortems: [docs/incidents/README.md](incidents/README.md).

## Zone model


| Zone       | Storage                                      | Tooling   | Purpose                                                 |
| ---------- | -------------------------------------------- | --------- | ------------------------------------------------------- |
| **Raw**    | Kafka + MinIO (Parquet) + `raw.`* (Postgres) | Flink SQL | Immutable landing; lake = archive, Postgres = dbt input |
| **Silver** | `silver.`*                                   | dbt       | Clean types, dedupe, incremental hygiene                |
| **Gold**   | `gold.`*                                     | dbt       | Business marts for BI (serving layer)                   |




## Key decisions



### Two Kafka topics (not one)

CoinGecko and Binance have different semantics (REST poll vs WS trades), throughput, and retention needs. Separate topics keep ownership clear and let Flink attach **independent consumer groups** per source.

### Flink SQL (not PyFlink)

The streaming layer is intentionally **declarative SQL**: easier to review in a portfolio, closer to how many teams run Flink in production, and keeps Python limited to ingest where I/O libraries shine.

### Storage layer (MinIO) + serving layer (PostgreSQL)

Flink **dual-writes** each tick to MinIO (Parquet, partitioned) and Postgres `raw`. Postgres remains the **serving path** for dbt and Metabase today; MinIO is the **durable archive** for reprocesos and future Iceberg. Details: [DATA_LAKE.md](DATA_LAKE.md).

### Binance throttle (~1 msg/s per coin)

Binance trades arrive at high frequency; CoinGecko polls every ~60s. Throttling avoids drowning Postgres and makes **cross-source comparison** meaningful (similar temporal granularity).

### `mart_latest_prices` stays CoinGecko-only

Existing BI dashboards expect one row per coin from the “reference” aggregator. Multi-source truth lives in `mart_latest_prices_by_source` and `mart_source_price_comparison`.

### Quality in two layers

- **dbt tests** — schema constraints at transform time (fast, versioned with models).
- **Great Expectations** — runtime freshness and cross-zone sanity checks on a schedule.

### Dead-letter queue for invalid payloads

Flink's Kafka sources tolerate malformed JSON (`json.ignore-parse-errors`) so one bad message can't crash the job — but that used to mean invalid records vanished with no trace. A second raw-format consumer per topic now classifies and routes anything that fails basic shape checks to `crypto-pulse.dlq`, monitored by the `dlq-monitor` service (Prometheus metric + alert). Details: [ADR 007](adr/007-dead-letter-queue.md).



### Observability split

- **Grafana + Prometheus** — pipeline health (throughput, lag, errors, Flink job count).
- **Metabase** — business questions on `gold.`*.

Alert rules live in `observability/prometheus/alerts.yml` and are validated in CI with `promtool`.

## Scaling & cost

Honest numbers for the **current portfolio footprint** (3 coins, 2 sources, default `.env.example` intervals). Use these in interviews — they show you have thought about production scale even if the repo runs on a laptop.

### Throughput (steady state)

| Source | Default interval | Approx. rate | Notes |
|--------|------------------|--------------|-------|
| CoinGecko REST | 60s poll | ~3 msgs/min | 3 coins × 1 event per poll |
| Binance WS | 1s throttle/symbol | ~180 msgs/min | 3 symbols × ~1 msg/s |
| **Combined ingest** | — | **~180–200 msgs/min** | ~260k events/day |

Flink dual-write fan-out: each valid event → 1 Postgres row + 1 Parquet object (~1.2 KiB average in demo runs). Expect **~300–400 MiB/day** in MinIO and a similar order of row growth in `raw.crypto_prices` before dbt incremental compaction in silver.

Dagster `transform_job` at 300s: **~288 dbt builds/day** — overkill for this volume; 60s is only for demo capture (`.env.demo`).

### What breaks first at 10× / 100× volume

| Multiplier | Likely bottleneck | Mitigation |
|------------|-------------------|------------|
| **10×** (~2k msgs/min) | Single Flink taskmanager CPU; Postgres `raw` index bloat | Add TM slots/partitions; partition `raw.crypto_prices` by `dt`; consider batching Flink sink |
| **100×** (~20k msgs/min) | Single Kafka broker disk; checkpoint duration; CoinGecko rate limit | MSK/multi-broker Kafka; decouple ingest from REST poll (cache layer); PyFlink or dedicated enrichment if SQL limits hit |
| **100×+** | Postgres as serving warehouse for all raw history | Archive raw to Iceberg ([ADR 005](adr/005-iceberg-roadmap.md)); Trino/Spark for silver; keep Postgres for gold only |

The architecture already separates **storage** (MinIO) from **serving** (Postgres) so the lake can grow without dragging BI queries down — but silver/gold still run in Postgres today.

### Cost sketch (AWS-equivalent, eu-west-1, rough 2026 list prices)

Portfolio runs **$0 on Docker Compose**. If you lifted the same shape to minimal managed AWS:

| Component | Sizing assumption | Order of magnitude |
|-----------|-------------------|--------------------|
| **S3 / lake** | 10 GiB/month + PUTs | **< $1/month** at current volume |
| **RDS PostgreSQL** | `db.t4g.small`, 20 GiB | **~$25–35/month** |
| **MSK (Kafka)** | 2× `kafka.t3.small` | **~$70–120/month** — often the dominant line item |
| **Flink** | Managed Analytics or self-hosted on ECS | **~$50–150/month** depending on always-on vs spot |
| **Observability** | Grafana Cloud free tier or self-hosted | **$0–20/month** |

**Total minimal cloud:** ~**$150–250/month** for always-on dev/staging parity. Production HA (multi-AZ, backups, MSK 3 brokers) is **3–5×** that.

LocalStack + Terraform in this repo ([`terraform/`](../terraform/README.md)) models the **S3 + IAM** slice without incurring AWS charges — useful for IaC review, not for performance testing.

### Security note (production)

Compose defaults (`pulse`/`pulse`, `minioadmin`) are intentional for local demos. In AWS: Secrets Manager or SSM Parameter Store for credentials, IAM roles for Flink/ingest tasks (no long-lived keys), private subnets for RDS/MSK, and bucket policies restricting lake access to the streaming role only. See [Known limitations](#known-limitations-honest-scope).

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


| Area      | Current state                  | Production next step                         |
| --------- | ------------------------------ | -------------------------------------------- |
| HA        | Single broker, single Flink TM | Multi-AZ Kafka, Flink checkpoint store       |
| Secrets   | Default passwords in compose   | Secrets manager + env injection              |
| Deploy    | Docker Compose local; Terraform + LocalStack for S3/IAM ([`terraform/`](../terraform/README.md)) | Managed RDS/MSK apply in real AWS account |
| Flink ops | Checkpoints + watchdog resubmit | Savepoints, managed Flink, alert on job loss |
| DLQ       | Implemented — invalid payloads split to `crypto-pulse.dlq`, `dlq-monitor` exposes metrics ([ADR 007](adr/007-dead-letter-queue.md)) | Auto-replay/reprocessing tooling, Slack/email alert routing |




## CI pipeline

On every push/PR (`.github/workflows/ci.yml`):

1. **pytest** — `coingecko_normalize`, `trade_normalize`, JSON Schema contract
2. **dbt parse/compile** — model graph integrity without a live DB
3. **docker compose config** + **promtool check rules** + **terraform validate/plan** (LocalStack) — infra sanity

