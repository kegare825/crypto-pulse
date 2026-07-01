# ADR 002: MinIO (storage) + PostgreSQL (serving)

## Status

Accepted (Phase C)

## Context

PostgreSQL alone works for a portfolio demo but mixes **cheap long-term history** with **low-latency BI serving**. Cloud migration needs an object-store-shaped archive (S3-compatible).

## Decision

Flink **dual-writes** each tick to:

1. **MinIO** — Parquet, Hive partitions `source/coin_id/dt=YYYY-MM-DD/` (storage / system of record for history)
2. **PostgreSQL `raw.crypto_prices`** — operational landing for dbt today (serving path)

Gold marts stay in Postgres for Metabase.

## Alternatives considered

| Option | Why not (for now) |
|--------|-------------------|
| Postgres only | Poor cost/retention story; no lakehouse narrative |
| MinIO only, drop Postgres raw | Breaks current dbt + Metabase path; bigger bang for portfolio |
| Iceberg immediately | Higher complexity before Parquet landing is proven |

## Consequences

**Pros:** Storage decoupled from serving; local MinIO maps to S3 in cloud; reprocesos from lake become possible.

**Cons:** Duplicate raw data; two systems to monitor; dbt still reads Postgres until Phase C2 external tables.

See [DATA_LAKE.md](../DATA_LAKE.md).
