# ADR 005: Iceberg on the roadmap (not Hudi or Delta yet)

## Status

Proposed (Phase C3)

## Context

Phase C1 writes **Parquet** to MinIO. The next step is a table format with ACID, schema evolution, and time travel — without moving Metabase off PostgreSQL gold.

## Decision

Plan **Apache Iceberg** as the next table format over the same bucket. Stay on plain Parquet until dual-write and partitioning are stable. Do **not** adopt Hudi or Delta Lake in this repo yet.

## Alternatives considered

| Option | Assessment |
|--------|------------|
| **Parquet only** | Current state — sufficient for portfolio; no ACID/time travel |
| **Apache Hudi** | Strong for CDC/upserts; our workload is append-mostly ticks — less natural story |
| **Delta Lake** | Mature on Databricks/Spark; more vendor/ecosystem coupling for an open-source portfolio narrative |
| **Iceberg** | Best fit for analytics lake on S3/MinIO + multiple engines (Flink, Trino, Spark); standard “open lakehouse” interview talking point |

## Consequences

**Pros:** Clear evolution path Parquet → Iceberg; gold remains Postgres serving layer.

**Cons:** Iceberg needs a catalog and more moving parts — deferred until C1 is demo-ready with screenshots and lake verification.
