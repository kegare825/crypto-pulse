# ADR 004: Flink SQL instead of PyFlink

## Status

Accepted

## Context

Streaming layer must land Kafka events into Postgres and MinIO. Python is already used for HTTP/WebSocket ingest.

## Decision

Implement the stream processor in **Flink SQL** (`flink/sql/pipeline.sql`): Kafka sources, dual sinks (JDBC + filesystem/Parquet), declarative and reviewable in Git.

## Alternatives considered

| Option | Why not |
|--------|---------|
| PyFlink | More code for the same pipeline; SQL matches how many teams operate Flink in production |
| Kafka Connect JDBC sink only | No unified SQL job for dual sink + transforms; less portfolio signal |
| Spark Structured Streaming | Valid, but Flink SQL was an explicit project constraint |

## Consequences

**Pros:** Pipeline diff-friendly; no JVM application code; aligns with “Flink SQL only” goal.

**Cons:** Complex logic (DLQ, rich dedup) harder in SQL; S3 sink needs extra JARs and Flink config.
