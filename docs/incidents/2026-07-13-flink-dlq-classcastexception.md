# Postmortem: Flink DLQ pipeline crash-loop (ClassCastException)

**Date:** 2026-07-13  
**Severity:** High — Flink streaming job stuck in `RESTARTING`, no new data to Postgres/MinIO  
**Duration:** ~15 minutes from first deploy of DLQ SQL until fix applied and job stabilized  
**Author:** Portfolio maintainer (blameless)

## Summary

After adding the dead-letter queue (ADR 007), the Flink SQL job submitted successfully but entered a crash-loop on the `kafka_coingecko_raw` source. The root cause was `JSON_VALUE(... RETURNING DOUBLE NULL ON ERROR)` in the DLQ validation views: Calcite's runtime cast threw `ClassCastException` when `price_usd` was serialized as a JSON **integer** (e.g. `62000`) instead of a float (`62000.0`). The fix was to extract `price_usd` as STRING and use `TRY_CAST(... AS DOUBLE)`, which returns NULL instead of throwing.

## Impact

| Area | Effect |
|------|--------|
| **Streaming** | Flink job `RESTARTING` with 1/8 tasks failed; dual-write to Postgres + MinIO paused |
| **Downstream** | dbt/Dagster continued on stale raw data; freshness SLAs would breach if prolonged |
| **DLQ** | Ironically, the DLQ path itself caused the outage — invalid messages were not the trigger |
| **Users** | Local demo/screenshot session blocked until job was cancelled, SQL fixed, and resubmitted |

No data corruption: checkpoints prevented duplicate writes once the job recovered.

## Timeline (UTC)

| Time | Event |
|------|-------|
| ~21:44 | Stack rebuilt with new DLQ SQL; `flink-submitter` exits 0 (SQL accepted by JobManager) |
| ~21:45 | Job `23f49713…` enters `RESTARTING`; exception on `coingecko.prices.raw` partition 1 offset 0 |
| ~21:46 | Diagnosis: `ClassCastException: Integer cannot be cast to Double` in `StreamExecCalc` (DLQ validation) |
| ~21:47 | Cancelled failing job; patched `flink/sql/pipeline.sql` (`TRY_CAST` instead of `RETURNING DOUBLE`) |
| ~21:48 | Rebuilt Flink images, resubmitted; single job `c5b3f801…` reaches `RUNNING` 8/8 tasks, 0 exceptions |

## Root cause

The DLQ validation views used:

```sql
JSON_VALUE(raw_value, '$.price_usd' RETURNING DOUBLE NULL ON ERROR) IS NULL
```

Flink SQL / Calcite documents `NULL ON ERROR` for malformed JSON paths, but the failure mode here was different:

1. `JSON_VALUE` **successfully** parsed `"price_usd": 62000` (JSON number without fractional part).
2. Calcite represented the value internally as `Integer`.
3. A downstream cast to `Double` for `RETURNING DOUBLE` threw `ClassCastException` **after** `JSON_VALUE` had already returned — outside the `NULL ON ERROR` guard.
4. The exception bubbled up through the Kafka source operator, failing the entire task and triggering Flink's restart strategy.

CoinGecko and Binance producers often emit whole-dollar prices as JSON integers. The main ingest path (`format = 'json'` with schema inference) tolerates this; the new raw-string DLQ path did not.

## Resolution

Replaced `RETURNING DOUBLE NULL ON ERROR` with a two-step pattern in both `coingecko_validation` and `binance_validation`:

```sql
TRY_CAST(JSON_VALUE(raw_value, '$.price_usd' NULL ON ERROR) AS DOUBLE) IS NULL
```

`TRY_CAST` is designed for this: invalid or incompatible conversions become SQL `NULL` without throwing at runtime.

Relevant code: `flink/sql/pipeline.sql` (comment block above `coingecko_validation` explains the pitfall).

Operational steps taken:

1. `curl -X PATCH` cancel on the crash-looping job ID.
2. `docker compose build` Flink images (SQL layer only).
3. `docker compose run --rm flink-submitter` to resubmit.
4. Verified via Flink REST API: `state: RUNNING`, `failed: 0`, `exceptions: []`.

## Prevention

| Action | Status |
|--------|--------|
| Document `RETURNING DOUBLE` pitfall in `pipeline.sql` comment | Done |
| Prefer `TRY_CAST` for all numeric extractions from raw JSON strings in Flink SQL | Done |
| Add integration test that publishes `price_usd` as integer JSON to Kafka and asserts DLQ job stays healthy | TODO — would require Flink test harness or mini-cluster |
| Monitor `FlinkNoRunningJobs` alert (already in `alerts.yml`) | Exists — would have fired if Grafana was wired to paging |

## Lessons learned

1. **SQL acceptance ≠ runtime safety.** Flink's SQL Client reported `Execute statement succeeded` for the views; the bug only appeared when the first real CoinGecko message hit the DLQ consumer group.
2. **`NULL ON ERROR` is not a blanket cast safety net.** It covers JSON parse/path errors, not Java type coercion after a successful extract.
3. **Test with production-shaped JSON.** Contract tests use floats; real APIs often emit integers for whole numbers.
4. **Postmortems belong in the repo.** This incident is more convincing evidence of operational maturity than a green CI badge alone.

## References

- [ADR 007: Dead-letter queue](../adr/007-dead-letter-queue.md)
- [Flink SQL pipeline](../../flink/sql/pipeline.sql) — `coingecko_validation`, `binance_validation`
- [Prometheus alert: FlinkNoRunningJobs](../../observability/prometheus/alerts.yml)
