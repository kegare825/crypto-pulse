# Data lake (MinIO) — storage vs serving

Crypto Pulse separates **storage** (cheap, immutable history) from **serving** (low-latency BI).

## Architecture

```
Kafka → Flink SQL ──┬──→ MinIO (Parquet, partitioned)   ← storage layer / system of record
                    └──→ Postgres raw.crypto_prices      ← operational cache for dbt today
                              ↓
                         dbt silver → gold
                              ↓
                         Postgres gold.*                  ← serving layer (Metabase)
```

| Layer | Technology | Role |
|-------|------------|------|
| **Storage** | MinIO (S3-compatible) + Parquet | Long-term raw history, reprocesos, future Iceberg |
| **Serving** | PostgreSQL `gold.*` | BI marts, Metabase, low-latency SQL |

PostgreSQL `raw` remains the **operational landing zone** for the current dbt pipeline. MinIO is the **durable archive** written in parallel by the same Flink job.

## Layout on object storage

Hive-style partitions (written by Flink filesystem sink):

```
s3://crypto-pulse/raw/crypto_prices/
  source=coingecko/
    coin_id=bitcoin/
      dt=2026-06-29/
        part-0-0.parquet
  source=binance/
    coin_id=ethereum/
      dt=2026-06-29/
        ...
```

Partition keys align with the event contract: `source`, `coin_id`, and calendar date `dt`.

## Local access

| Service | URL | Credentials |
|---------|-----|-------------|
| MinIO API | http://localhost:9000 | `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` (default `minioadmin`) |
| MinIO Console | http://localhost:9001 | same |

Verify objects after the pipeline is running:

```bash
bash scripts/verify_lake.sh
```

## Flink dual sink

`flink/sql/pipeline.sql` uses `EXECUTE STATEMENT SET` to write one unified stream to:

1. **JDBC** → `raw.crypto_prices` (unchanged for dbt)
2. **filesystem + parquet** → `s3a://crypto-pulse/raw/crypto_prices`

Required Flink plugins (see `flink/Dockerfile`):

- `flink-s3-fs-hadoop` — S3A access to MinIO
- `flink-sql-parquet` — Parquet format

MinIO endpoint is configured via `s3.endpoint` and path-style access in Flink `FLINK_PROPERTIES`.

## Roadmap: Iceberg (Phase C3)

**Not implemented yet.** When MinIO + Parquet is stable:

1. Register Iceberg tables over the same bucket (or migrate layout)
2. Point silver dbt models at Iceberg / Trino / DuckDB external tables
3. Keep **gold in Postgres** for Metabase

Iceberg adds ACID, time travel, and compaction — valuable for portfolio storytelling once the basic lake path works.

## Cloud migration

| Local | Cloud |
|-------|-------|
| MinIO | AWS S3 / GCS / Azure Blob |
| `s3.endpoint` | Remove (use default regional endpoint) |
| `s3.path-style-access` | Often `false` on AWS |
| Bucket `crypto-pulse` | Same name + IAM role for Flink |

Terraform modules (Phase D) would provision bucket + IAM; Flink config changes are environment variables only.

## Known limitations

- **Two copies of raw data** — Postgres + MinIO; Postgres is convenience, MinIO is archive
- **No compaction job yet** — small files accumulate at low volume (acceptable for portfolio)
- **dbt still reads Postgres raw** — lake is write-only until Phase C2 external tables
